--[[
--]]

require("neorg.modules.base")
require("neorg.external.helpers")

local module = neorg.modules.create("core.norg.esupports.hop")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.keybinds",
            "core.integrations.treesitter",
            "core.ui",
        },
    }
end

module.load = function()
    module.required["core.keybinds"].register_keybind(module.name, "hop-link")
end

module.config.public = {
    lookahead = true,
}

module.public = {
    extract_link_node = function()
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        if not ts_utils then
            return
        end

        local current_node = ts_utils.get_node_at_cursor()
        return module.required["core.integrations.treesitter"].find_parent(current_node, { "link", "strict_link" })
            or (module.config.public.lookahead and module.public.lookahead_link_node())
    end,

    -- TODO: Make work for new links and stop it from always jumping to latest `[` when there is no link
    lookahead_link_node = function()
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        if not ts_utils then
            return
        end

        local line = vim.api.nvim_get_current_line()
        local current_row = vim.api.nvim_win_get_cursor(0)[1]
        local index = line:find("%[")

        while index do
            vim.api.nvim_win_set_cursor(0, { current_row, index - 1 })

            local current_node = ts_utils.get_node_at_cursor()
            local link_node = module.required["core.integrations.treesitter"].find_parent(
                current_node,
                { "link", "strict_link" }
            )

            if link_node then
                return link_node
            end

            index = line:find("%[", index + 1)
        end
    end,

    parse_link = function(link_node)
        if not link_node or not vim.tbl_contains({ "link", "strict_link" }, link_node:type()) then
            return
        end

        local query_text = [[
            (link
                (link_file
                    location: (link_file_text) @link_file_text
                )?
                (link_location
                    type: [
                        (link_location_url)
                        (link_location_generic)
                        (link_location_external_file)
                        (link_location_marker)
                        (link_location_heading1)
                        (link_location_heading2)
                        (link_location_heading3)
                        (link_location_heading4)
                        (link_location_heading5)
                        (link_location_heading6)
                    ] @link_type
                    text: (link_location_text) @link_location_text
                )?
                (link_description
                    text: (link_text) @link_description
                )?
            )
        ]]

        local document_root = module.required["core.integrations.treesitter"].get_document_root()

        if not document_root then
            return
        end

        local query = vim.treesitter.parse_query("norg", query_text)
        local range = module.required["core.integrations.treesitter"].get_node_range(link_node)

        local parsed_link_information = {}

        for id, node in query:iter_captures(document_root, 0, range.row_start, range.row_end + 1) do
            local capture = query.captures[id]

            local extract_node_text = neorg.lib.wrap(
                module.required["core.integrations.treesitter"].get_node_text,
                node
            )

            parsed_link_information[capture] = parsed_link_information[capture]
                or neorg.lib.match({
                    capture,
                    link_file_text = extract_node_text,
                    link_type = neorg.lib.wrap(string.sub, node:type(), string.len("link_location_") + 1),
                    link_location_text = extract_node_text,
                    link_description = extract_node_text,

                    default = function()
                        log.error("Unknown capture type encountered when parsing link:", capture)
                    end,
                })
        end

        return parsed_link_information
    end,

    locate_link_target = function(parsed_link_information)
        --- A pointer to the target buffer we will be parsing.
        -- This may change depending on the target file the user gave.
        local buf_pointer = vim.api.nvim_get_current_buf()

        -- Check whether our target is from a different file
        if parsed_link_information.link_file_text then
            -- Expand special chars like `$`
            local workspace, custom_workspace_path = parsed_link_information.link_file_text:match("^($([^/]*))")

            local dirman = neorg.modules.get_module("core.norg.dirman")

            if not dirman then
                log.error("Unable to read file stored in link: core.norg.dirman was not loaded.")
                return
            end

            if custom_workspace_path and custom_workspace_path:len() > 0 then
                local path = dirman.get_workspace(custom_workspace_path)

                if not path then
                    log.trace("Unable to go to link: workspace does not exist")
                    return
                end

                parsed_link_information.link_file_text = path
                    .. parsed_link_information.link_file_text:sub(custom_workspace_path:len() + 2)
            elseif workspace then
                parsed_link_information.link_file_text = dirman.get_current_workspace()[2]
                    .. parsed_link_information.link_file_text:sub(workspace:len() + 1)
            end

            parsed_link_information.link_file_text = vim.fn.fnamemodify(
                parsed_link_information.link_file_text .. ".norg",
                ":p"
            )

            if parsed_link_information.link_file_text ~= vim.fn.expand("%:p") then
                -- We are dealing with a foreign file
                log.warn("We are dealing with a foreign file")

                -- HACK(vhyrro): This is a hacky way of making what we want work
                -- For some reason if we don't set the buf_pointer to the current buffer
                -- then treesitter cannot parse it at all. Loading the buffer with
                -- vim.fn.bufload() does not help either. Sad times.
                buf_pointer = vim.uri_to_bufnr("file://" .. parsed_link_information.link_file_text)
                vim.api.nvim_set_current_buf(buf_pointer)
                vim.api.nvim_buf_set_option(buf_pointer, "buflisted", true)
            end
        end

        return neorg.lib.match({
            parsed_link_information.link_type,

            url = function()
                local destination = parsed_link_information.link_location_text

                if neorg.configuration.os_info == "linux" then
                    vim.cmd('silent !xdg-open "' .. vim.fn.fnameescape(destination) .. '"')
                elseif neorg.configuration.os_info == "mac" then
                    vim.cmd('silent !open "' .. vim.fn.fnameescape(destination) .. '"')
                else
                    vim.cmd('silent !start "' .. vim.fn.fnameescape(destination) .. '"')
                end

                return {}
            end,

            external_file = function()
                vim.cmd("e " .. vim.fn.fnameescape(parsed_link_information.link_location_text))
                return {}
            end,

            default = function()
                -- Dynamically forge query
                local query_str = string.format(
                    [[
                        (%s
                            (%s_prefix)
                            title: (paragraph_segment) @title
                        )
                    ]],
                    parsed_link_information.link_type,
                    parsed_link_information.link_type
                )

                local document_root = module.required["core.integrations.treesitter"].get_document_root(buf_pointer)

                if not document_root then
                    -- Because of the above hack we then have to forcefully
                    -- delete the buffer every time we can't find the item.
                    vim.api.nvim_buf_delete(buf_pointer, {
                        force = true,
                    })
                    return
                end

                local query = vim.treesitter.parse_query("norg", query_str)

                for id, node in query:iter_captures(document_root, buf_pointer) do
                    local capture = query.captures[id]

                    if capture == "title" then
                        local original_title = module.required["core.integrations.treesitter"].get_node_text(node)
                        local title = original_title:gsub("[%s\\]", "")
                        local target = parsed_link_information.link_location_text:gsub("[%s\\]", "")

                        if title == target then
                            return {
                                original_title = original_title,
                                node = node,
                                buffer = buf_pointer,
                            }
                        end
                    end
                end

                vim.api.nvim_buf_delete(buf_pointer, {
                    force = true,
                })
            end,
        })
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.norg.esupports.hop.hop-link" then
        local link_node_at_cursor = module.public.extract_link_node()

        if not link_node_at_cursor then
            log.trace("No link under cursor.")
            return
        end

        local parsed_link = module.public.parse_link(link_node_at_cursor)

        if not parsed_link then
            return
        end

        local located_link_information = module.public.locate_link_target(parsed_link)

        if located_link_information then
            if not vim.tbl_isempty(located_link_information) then
                if located_link_information.buffer ~= vim.api.nvim_get_current_buf() then
                    -- TODO: Change this behaviour to work with splits too!
                    vim.api.nvim_buf_set_option(located_link_information.buffer, "buflisted", true)
                    vim.api.nvim_set_current_buf(located_link_information.buffer)
                end

                local range = module.required["core.integrations.treesitter"].get_node_range(
                    located_link_information.node
                )
                vim.api.nvim_win_set_cursor(0, { range.row_start + 1, range.column_start })
            end

            return
        end

        local selection = module.required["core.ui"].begin_selection(
            module.required["core.ui"].create_split("link-not-found")
        )
            :listener("delete-buffer", {
                "<Esc>",
            }, function(self)
                self:destroy()
            end)
            :apply({
                warning = function(self, text)
                    return self:text("WARNING: " .. text, "TSWarning")
                end,
                desc = function(self, text)
                    return self:text(text, "TSComment")
                end,
            })

        selection
            :title("Link not found - what do we do now?")
            :blank()
            :text("There are a few actions that you can perform whenever a link cannot be located.", "Normal")
            :text("Press one of the available keys to perform your desired action.")
            :warning("These flags currently do not work, this is a beta build.")
            :blank()
            :desc("The most common action will be to try and fix the link.")
            :desc("Fixing the link will perform a fuzzy search on every item in the file")
            :desc("and make the link point to the closest match:")
            :flag("f", "Attempt to fix the link")
            :blank()
            :desc("Does the same as the above keybind, however limits matches to those")
            :desc("of the same type as the link. This means that if your link points to")
            :desc("a level-1 heading a fuzzy search will be done only for level-1 headings:")
            :flag("F", "Attempt to fix the link (with stricter searches)")
            :blank()
            :desc("Instead of fixing the link you may actually want to create the target:")
            :flag("a", "Place target above current link parent")
            :flag("b", "Place target below current link parent")
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.esupports.hop.hop-link"] = true,
    },
}

return module
