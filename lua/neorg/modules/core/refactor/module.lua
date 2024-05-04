--[[
    file: Refactor-Module
    title: Rename Things Without Much Worry
    summary: A module that allows for file and header refactors without breaking existing links
    internal: false
    ---

This module provides a way to move files around without breaking existing links to or from the
file. It also lets you rename headers without breaking links to the header. Works on all files
in the workspace, if a file is open, it will use the buffer contents instead of the file contents
so unsaved changes are accounted for.

## Limitations

- When renaming a file, and links inside the file will be converted to workspace relative links
- Links that include a file path to their own file (ie. `{:path/to/blah:}` while in `blah.norg`)
  are not supported

## Commands

- `Neorg refactor rename file`
- `Neorg refactor rename header`
--]]

local neorg = require("neorg.core")
local Path = require("pathlib")
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

local link_tools, dirman, ts
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
                            args = 0,
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
        ---@param link Link
        local current_file_changes = module.public.fix_links(current_path, function(link)
            local link_path, rel = link_tools.where_does_this_link_point(current_path, link)
            if link_path and rel then
                -- it's relative to the file location, so we might have to change it
                local lp = Path(link_path):relative_to(Path(new_path):parent(), true):resolve_copy()
                if not lp then
                    return
                end

                local range = link.file and link.file.range
                if link.type and link.type.text == "/ " then
                    range = link.text.range
                else
                    return
                end
                return tostring(lp), unpack(range)
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
            if file == current_path then goto continue end
            ---@param link Link
            local file_changes = module.public.fix_links(file, function(link)
                local link_path, _ = link_tools.where_does_this_link_point(file, link)
                if link_path == current_path then
                    local new_link
                    if Path(link):is_relative() then
                        new_link = Path(new_path):relative_to(Path(file))
                    else
                        new_link = new_ws_path
                    end
                    return new_link, unpack(link.file.range)
                end
            end)
            if #file_changes > 0 then
                total_changed.files = total_changed.files + 1
                total_changed.links = total_changed.links + #file_changes
                local file_uri = vim.uri_from_fname(file)
                wsEdit.changes[file_uri] = file_changes
            end

            ::continue::
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

    rename_heading = function(line_number, new_heading)
        line_number = line_number - 1
        local buf = vim.api.nvim_get_current_buf()
        local node = ts.get_first_node_on_line(buf, line_number)
        local line = vim.api.nvim_buf_get_lines(buf, line_number, line_number + 1, false)
        local prefix = line[1]:match("^%*+ ")
        local new_prefix = new_heading:match("^%*+ ")
        local new_name = new_heading:sub(#new_prefix + 1)
        if not node then
            return
        end

        local title = node:field("title")[1]
        if not title then
            return
        end

        local title_text = ts.get_node_text(title)
        local total_changed = {
            files = 0,
            links = 0,
        }

        -- headings with checkbox items have this extra white space.
        title_text = string.gsub(title_text, "^ ", "")

        ---@type lsp.WorkspaceEdit
        local wsEdit = { changes = {} }
        ---@param link Link
        local changes = module.public.fix_links(buf, function(link)
            local link_prefix = link.type and link.type.text
            local link_heading = link.text and link.text.text
            -- NOTE: This will not work for {:path/to/current/file:# heading} but who would do that..
            if not link.file and (link_prefix == "# " or link_prefix == prefix) and link_heading == title_text then
                local p = new_prefix
                if link_prefix == "# " then
                    p = "# "
                end
                return ("{%s%s}"):format(p, new_name)
            end
        end)

        local file_uri = vim.uri_from_bufnr(buf)
        wsEdit.changes[file_uri] = changes

        -- change the heading in our file too
        table.insert(wsEdit.changes[file_uri], {
            newText = new_heading .. "\n",
            range = {
                start = {
                    line = line_number,
                    character = 0,
                },
                ["end"] = {
                    line = line_number + 1,
                    character = 0,
                },
            },
        })
        if #changes - 1 > 0 then
            total_changed.files = total_changed.files + 1
            total_changed.links = total_changed.links + #changes - 1
        end

        -- loop through all the files
        local ws_name = dirman.get_current_workspace()[1]
        local files = dirman.get_norg_files(ws_name)

        local current_path = vim.api.nvim_buf_get_name(0)
        for _, file in ipairs(files) do
            if file == current_path then goto continue end

            ---@param link Link
            changes = module.public.fix_links(file, function(link)
                local link_path = link_tools.where_does_this_link_point(file, link)
                local link_heading = link.text and link.text.text
                local link_prefix = link.type and link.type.text
                if not link_heading or not link_prefix then
                    return
                end

                if
                    (link_prefix == "# " or link_prefix == prefix)
                    and link_heading == title_text
                    and link_path == current_path
                then
                    local p = new_prefix
                    if link_prefix == "# " then
                        p = "# "
                    end
                    return ("%s%s"):format(p, new_name),
                        link.type.range[1],
                        link.type.range[2],
                        link.text.range[3],
                        link.text.range[4]
                end
            end)
            if #changes > 0 then
                wsEdit.changes[vim.uri_from_fname(file)] = changes
                total_changed.files = total_changed.files + 1
                total_changed.links = total_changed.links + #changes
            end

            ::continue::
        end

        vim.lsp.util.apply_workspace_edit(wsEdit, "utf-8")
        vim.notify(
            ("[Neorg] renamed %s to %s\nChanged %d links across %d files."):format(
                title_text,
                new_name,
                total_changed.links,
                total_changed.files
            ),
            vim.log.levels.INFO
        )
    end,

    ---Abstract function to generate TextEdits that alter matching links
    ---@param source number | string bufnr or filepath
    ---@param fix_link function takes a string, the current link, returns a string, the new link,
    ---or nil if this shouldn't be changed
    fix_links = function(source, fix_link)
        local links = nil
        links = link_tools.get_links(source)

        local edits = {}
        for _, link in ipairs(links) do
            local new_link, start_line, start_char, end_line, end_char = fix_link(link)
            if new_link then
                ---@type lsp.TextEdit
                local text_edit = {
                    newText = new_link,
                    range = {
                        start = {
                            line = start_line or link.range[1],
                            character = start_char or link.range[2],
                        },
                        ["end"] = {
                            line = end_line or link.range[3],
                            character = end_char or link.range[4],
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
            vim.schedule(function()
                vim.ui.input({ prompt = "New Path: ", default = current }, function(text)
                    module.public.rename_file(current, text)
                end)
            end)
        end
    end,

    ["refactor.rename.heading"] = function(event)
        local line_number = event.cursor_position[1]
        local prefix = string.match(event.line_content, "^%s*%*+ ")
        if not prefix then -- this is a very very simple check that we're on a heading line. We use TS in the actual rename_heading function
            return
        end

        vim.schedule(function()
            vim.ui.input({ prompt = "New Heading: ", default = event.line_content }, function(text)
                if not text then return end

                module.public.rename_heading(line_number, text)
            end)
        end)
    end,
}

return module
