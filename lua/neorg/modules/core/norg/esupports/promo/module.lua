local module = neorg.modules.create("core.norg.esupports.promo")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.keybinds",
        },
    }
end

module.load = function()
    module.required["core.keybinds"].register_keybinds(
        module.name,
        (function()
            local keys = vim.tbl_keys(module.events.subscribed["core.keybinds"])

            for i, key in ipairs(keys) do
                keys[i] = key:sub(module.name:len() + 2)
            end

            return keys
        end)()
    )
end

module.config.public = {}

module.public = {
    promote = function(event)
        local cursor_pos = vim.api.nvim_win_get_cursor(event.window)
        local cursor_node = module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor(0, true)
    end,
    demote = function(event)
        local cursor_pos = vim.api.nvim_win_get_cursor(event.window)
        local cursor_node = module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor(0, true)
    end,
}

module.on_event = function(event)
    if event.split_type[1] == "core.keybinds" then
        if event.split_type[2] == "core.norg.esupports.promo.promote" then
            module.public.promote(event)
        elseif event.split_type[2] == "core.norg.esupports.promo.demote" then
            module.public.demote(event)
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.esupports.promo.promote"] = true,
        ["core.norg.esupports.promo.demote"] = true,
    },
}

return module
