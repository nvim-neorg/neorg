--[[
--]]

require("neorg.modules.base")

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

        -- local current_node = ts_utils.get_node_at_cursor()
    end,

    parse_link = function(link_node)
        if not link_node or not vim.tbl_contains({ "link", "strict_link" }, link_node:type()) then
            return
        end

        local structure = {
            link_text = {
                child = 0,
                optional = false,
                extract = function(node, ts)
                    return ts.get_node_text(node:named_child(0))
                end,
            },

            link_location = {
                child = 1,
                optional = false,
                extract = function(node, ts)
                    if node:named_child(0):type() == "link_file" then
                        return {
                            link_file = ts.get_node_text(node:named_child(0):named_child(0)),
                            link_end = node:named_child(1) and {
                                type = node:named_child(1):named_child(0):type(),
                                text = ts.get_node_text(node:named_child(1):named_child(1)),
                            },
                        }
                    end

                    return {
                        link_end = {
                            type = node:named_child(0):named_child(0):type(),
                            text = ts.get_node_text(node:named_child(0):named_child(1)),
                        },
                    }
                end,
            },
        }

        local result = {}
        local index = 0

        for name, data in pairs(structure) do
            local child = link_node:named_child(data.child - index)

            if not child then
                if not data.optional then
                    return
                end

                index = index + 1
            end

            result[name] = data.extract(child, module.required["core.integrations.treesitter"])
        end

        return result
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

        log.warn(parsed_link)
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.esupports.hop.hop-link"] = true,
    },
}

return module
