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

            local extract_node_text = neorg.lib.wrap(module.required["core.integrations.treesitter"].get_node_text, node)

            parsed_link_information[capture] = parsed_link_information[capture] or neorg.lib.match({
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

        log.warn(parsed_link)
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.esupports.hop.hop-link"] = true,
    },
}

return module
