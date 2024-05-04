--[[
    file: Refactor-Module
    title: Move Files Fearlessly
    summary: A module that allows for moving files around without breaking links to or from the file
    internal: false
    ---

This module will provide a way to move files around without breaking existing links to or from the
file.

The aim is to provide a command to move them, but also to hook nvim's lsp handlers in order to
support moving files via something like Oil, which fires the correct events when files are moved.
--]]

local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.refactor")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.dirman",
            "core.dirman.utils",
            "core.neorgcmd",
            "core.link-tools",
            "core.ui.text_popup",
        },
    }
end

local link_tools, dirman, dirman_utils, popup
module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        -- TODO: we should probably make a few different commands
        refactor = {
            min_args = 0, -- Tells neorgcmd that we want at least one argument for this command
            max_args = 1, -- Tells neorgcmd we want no more than one argument
            -- args = 0, -- Setting this variable instead would be the equivalent of min_args = 1 and max_args = 1
            name = "refactor",
            condition = "norg",
            subcommands = {
                rename = {
                    args = 1,
                    name = "refactor.rename",
                    subcommands = {
                        file = {
                            min_args = 0,
                            max_args = 1,
                            name = "refactor.rename.file",
                        },
                    },
                },
            },
        },
    })
    link_tools = module.required["core.link-tools"]
    dirman = module.required["core.dirman"]
    dirman_utils = module.required["core.dirman.utils"]
    popup = module.required["core.ui.text_popup"]
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["refactor.rename.file"] = true,
    },
}

module.on_event = function(event)
    P(event)
    if module.private[event.split_type[2]] then
        P("here")
        module.private[event.split_type[2]](event.content[1])
    end
end

---@class lsp.TextEdit
---@field range lsp.Range
---@field newText string

---@class lsp.WorkspaceEdit
---@field changes table<string, lsp.TextEdit[]>

module.public = {
    ---move the current file from one location to another, and update all the links to/from the file
    ---in the current workspace
    ---@param current_path any
    ---@param new_path any
    rename_file = function(current_path, new_path)
        new_path = vim.fs.normalize(new_path)
        current_path = vim.fs.normalize(current_path)
        local total_changed = { files = 0, links = 0 }

        ---@type lsp.WorkspaceEdit
        local wsEdit = { changes = {} }
        local current_file_changes = module.public.fix_out_links(current_path, new_path)
        if #current_file_changes > 0 then
            total_changed.files = total_changed.files + 1
            total_changed.links = total_changed.links + #current_file_changes
            local current_path_uri = vim.uri_from_fname(new_path)
            wsEdit.changes[current_path_uri] = current_file_changes
        end

        local ws_name = dirman.get_current_workspace()[1]
        local ws_path = dirman.get_current_workspace()[2]

        local files = dirman.get_norg_files(ws_name)
        local new_ws_path = "$" .. string.gsub(new_path, "^" .. ws_path, "")
        new_ws_path = string.gsub(new_ws_path, "%.norg$", "")
        for _, file in ipairs(files) do
            local file_changes = module.public.fix_in_links_in_file(current_path, file, new_ws_path)
            if #file_changes > 0 then
                total_changed.files = total_changed.files + 1
                total_changed.links = total_changed.links + #file_changes
                local file_uri = vim.uri_from_fname(file)
                wsEdit.changes[file_uri] = file_changes
            end
        end

        os.rename(current_path, new_path)
        vim.cmd.e(new_path)
        vim.lsp.util.apply_workspace_edit(wsEdit, "utf-8")
        vim.notify(
            ("[Neorg] renamed %s to %s\nChanged %d links across %d files."):format(
                current_path,
                new_path,
                total_changed.links,
                total_changed.files
            ),
            vim.log.levels.INFO
        )
    end,

    -- NOTE: I want to use LSP text changes to update all the files in one go via a call
    -- to `vim.lsp.util.apply_workspace_edit()` where a WorkspaceEdit is in the form:
    -- `{ changes = { [fileuri]: TextEdit[] }[] }`

    ---fixes the links _in_ the file being moved
    ---@param current_path string
    ---@param new_path string
    ---@return lsp.TextEdit[]
    fix_out_links = function(current_path, new_path)
        current_path = vim.fs.normalize(current_path)
        new_path = vim.fs.normalize(new_path)
        local current_dir = vim.fs.dirname(current_path)
        local current_ws_path = dirman.get_current_workspace()[2]
        -- current buffer links
        local links = link_tools.get_file_links_from_buf(0)
        local document_edits = {}
        for _, link in ipairs(links) do
            local path_text = link[1]
            if not string.match(path_text, "^%$") then
                local ws_rel_link = dirman_utils.to_workspace_relative(current_dir, path_text, current_ws_path)

                ---@type lsp.TextEdit
                local text_edit = {
                    newText = ws_rel_link,
                    range = {
                        start = {
                            line = link[2],
                            character = link[3],
                        },
                        ["end"] = {
                            line = link[4],
                            character = link[5],
                        },
                    },
                }
                table.insert(document_edits, text_edit)
            end
        end
        return document_edits
    end,

    ---generate text edits to fix links in `file_path` to `current_path` so that they point to
    ---`new_path`
    ---@param current_path string full path to norg file before it's moved
    ---@param file_path string full path to the file we're checking for links to the current_path
    ---@param new_ws_path string ws relative path to the new norg file. In form: `$/tools/git`
    ---@return lsp.TextEdit[]
    fix_in_links_in_file = function(current_path, file_path, new_ws_path)
        local file_dir = vim.fs.dirname(file_path)
        local current_ws = dirman.get_current_workspace()[2]
        local current_path_wsr = current_path:gsub("^" .. current_ws, "")
        current_path_wsr = "$" .. current_path_wsr:gsub("%.norg$", "")

        local links = link_tools.get_file_links_from_file(file_path)
        local document_edits = {}
        for _, link in ipairs(links) do
            local path_text = link[1]
            -- figure out where the link is pointing, and compare it to the `current_path`
            -- if it's equal, the we change it to the new workspace path`
            if not string.match(path_text, "^%$") then
                -- this is a relative path, and we'll want to see where it's pointing
                local ws_rel_link_text = dirman_utils.to_workspace_relative(current_ws, file_dir, path_text)
                if ws_rel_link_text == current_path_wsr then
                    ---@type lsp.TextEdit
                    local text_edit = {
                        newText = new_ws_path,
                        range = {
                            start = {
                                line = link[2],
                                character = link[3],
                            },
                            ["end"] = {
                                line = link[4],
                                character = link[5],
                            },
                        },
                    }
                    table.insert(document_edits, text_edit)
                end
            else
                -- handle existing ws relative links too
                if path_text == current_path_wsr then
                    ---@type lsp.TextEdit
                    local text_edit = {
                        newText = new_ws_path,
                        range = {
                            start = {
                                line = link[2],
                                character = link[3],
                            },
                            ["end"] = {
                                line = link[4],
                                character = link[5],
                            },
                        },
                    }
                    table.insert(document_edits, text_edit)
                end
            end
        end
        return document_edits
    end,
}

module.private = {
    ["refactor.rename.file"] = function(new_path)
        local current = vim.api.nvim_buf_get_name(0)
        if new_path then
            module.public.rename_file(current, new_path)
        else
            popup.create_prompt("RenameNeorgFile", "New Path: ", function(text)
                module.public.rename_file(text)
            end, {
                center_x = true,
                center_y = true,
            }, {
                width = 50,
                height = 1,
                row = 10,
                col = 0,
            })
        end
    end,
}

return module
