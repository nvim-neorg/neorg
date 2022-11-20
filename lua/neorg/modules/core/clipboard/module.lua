local module = neorg.modules.create("core.clipboard")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
        }
    }
end

module.load = function()
    neorg.modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybinds(module.name, { "yank" })
    end)
end

module.private = {
    callbacks = {},
}

module.public = {
    set_callback = function(node_type, func)
        module.private.callbacks[node_type] = func
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.clipboard.yank" then
        vim.api.nvim_feedkeys("y", "n", true)

        local node = module.required["core.integrations.treesitter"].get_first_node_on_line(event.buffer, event.cursor_position[1] - 1)

        while node:parent() do
            if module.private.callbacks[node:type()] then
                local register = vim.fn.getreg("\"")
                vim.fn.setreg("\"", module.private.callbacks[node:type()](node, register) or register)
                return
            end

            node = node:parent()
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.clipboard.yank"] = true,
    },
}

return module
