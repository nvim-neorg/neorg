--[[
    file: Refactor-Module
    title: Move Files Fearlessly
    summary: A module that allows for moving files around without breaking links to or from the file
    internal: false
    ---

This module provides a way to move files around without breaking existing links to or from the file.
Originally, this module planned to implement more common refactors, but LSP is around the corner, so
this module will likely be phased out in favor of LSP code actions.

Commands:
Neorg refactor rename file [new_file_path]
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

local link_tools, dirman, dirman_utils, popup, ts
module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        refactor = {
            min_args = 0,
            max_args = 1,
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
                        heading = {
                            min_args = 0,
                            max_args = 1,
                            name = "refactor.rename.heading",
                        },
                    },
                },
            },
        },
    })
    ts = module.required["core.integrations.treesitter"]
    link_tools = module.required["core.link-tools"]
    dirman = module.required["core.dirman"]
    dirman_utils = module.required["core.dirman.utils"]
    popup = module.required["core.ui.text_popup"]
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["refactor.rename.file"] = true,
        ["refactor.rename.heading"] = true,
    },
}

module.on_event = function(event)
    if module.private[event.split_type[2]] then
        module.private[event.split_type[2]](event)
    end
end

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
        local current_file_changes = module.public.fix_links(current_path, true, function(link_text)
            local link_path, _ = link_tools.where_does_this_link_point(current_path, link_text)
            if link_path and not string.match(link_text, "^{:%$") then
                link_path = link_path:gsub("%.norg$", "")
                local ws_rel_link = dirman_utils.to_workspace_relative(link_path)
                return string.gsub(link_text, "{:.*:(.*)}", ("{:%s:%%1}"):format(ws_rel_link))
            end
        end)
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
            local file_changes = module.public.fix_links(file, true, function(link_text)
                local link_path, _ = link_tools.where_does_this_link_point(file, link_text)
                if link_path == current_path then
                    link_path = link_path:gsub("%.norg$", "")
                    return string.gsub(link_text, "{:.*:(.*)}", ("{:%s:%%1}"):format(new_ws_path))
                end
            end)
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

    rename_heading = function(line, new_name)
        line = line - 1
        local buf = vim.api.nvim_get_current_buf()
        local node = ts.get_first_node_on_line(buf, line)
        if not node then
            return
        end

        local title = node:field("title")[1]
        if not title then
            return
        end

        local title_text = ts.get_node_text(title)

        -- headings with TODO items have this extra white space.
        title_text = string.gsub(title_text, "^ ", "")

        local ws_changes = {
            [vim.uri_from_bufnr(buf)] = module.public.fix_links(buf, true, function(link_text)
                local link_prefix = link_text:match("^[#*]+")
                if link_text:match(("{.*(%s %s)}"):format(link_prefix, title_text)) then
                    return string.gsub(link_text, ("{(.*%s )}"):format(link_prefix), ("{%1%s}"):format(new_name))
                end
            end),
        }

        -- loop through all the files
        local ws_name = dirman.get_current_workspace()[1]
        -- local ws_path = dirman.get_current_workspace()[2]

        local files = dirman.get_norg_files(ws_name)

        local current_path = vim.api.nvim_buf_get_name(0)
        for _, file in ipairs(files) do
            ws_changes[vim.uri_from_fname(file)] = module.public.fix_links(file, true, function(link_text)
                local link_path, _ = link_tools.where_does_this_link_point(file, link_text)
                if link_path == current_path then
                    link_path = link_path:gsub("%.norg$", "")
                    return string.gsub(link_text, "{(:.*:)?.*}", ("{:%%1:%s}"):format(new_name))
                end
            end)
        end
    end,

    ---Abstract function to generate TextEdits that alter matching links
    ---@param source number | string bufnr or filepath
    ---@param with_heading boolean fill link text or just the file path?
    ---@param fix_link function takes a string, the current link, returns a string, the new link,
    ---or nil if this shouldn't be changed
    fix_links = function(source, with_heading, fix_link)
        local links = nil
        if type(source) == "number" then
            links = link_tools.get_file_links_from_buf(source, with_heading)
        elseif type(source) == "string" then
            links = link_tools.get_file_links_from_file(source, with_heading)
        end

        local edits = {}
        for _, link in ipairs(links) do
            local link_text = link[1]
            local new_link = fix_link(link_text)
            if new_link then
                ---@type lsp.TextEdit
                local text_edit = {
                    newText = new_link,
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
                table.insert(edits, text_edit)
            end
        end

        return edits
    end,
}

module.private = {
    ["refactor.rename.file"] = function(event)
        local new_path = event.content[1]
        local current = vim.api.nvim_buf_get_name(0)
        if new_path then
            module.public.rename_file(current, new_path)
        else
            popup.create_prompt("RenameNeorgFile", "New Path: ", function(text, ctx)
                ctx.close()
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

    ["refactor.rename.heading"] = function(event)
        local line = event.cursor_position[1]
        local new_name = event.content[1]
        local prefix = string.match(event.line_content, "^%s*%*+ ")
        if not prefix then
            return
        end
        if new_name then
            new_name = string.gsub(event.line_content, "^%s*%*+ ", "")
            module.public.rename_heading(line, new_name)
        else
            popup.create_prompt("RenameNeorgHeading", "New Heading: " .. prefix, function(text, ctx)
                ctx.close()
                module.public.rename_heading(line, text)
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
