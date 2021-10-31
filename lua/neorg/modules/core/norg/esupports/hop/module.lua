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

module.public = {
    extract_link_node = function()
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        if not ts_utils then
            return
        end

        local current_node = ts_utils.get_node_at_cursor()
        return module.required["core.integrations.treesitter"].find_parent(current_node, "link")
    end,

    parse_link = function(link_node) end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.norg.esupports.hop.hop-link" then
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.esupports.hop.hop-link"] = true,
    },
}

return module
