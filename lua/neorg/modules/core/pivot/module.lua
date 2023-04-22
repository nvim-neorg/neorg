--[[
--]]

local module = neorg.modules.create("core.pivot")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.load = function()
    neorg.modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybind(module.name, "toggle-list-type")
    end)
end

module.on_event = function(event)
    if event.split_type[2] == "core.pivot.toggle-list-type" then
        local node = module.required["core.integrations.treesitter"].get_first_node_on_line(
            event.buffer,
            event.cursor_position[1] - 1
        )

        if not node then
            log.error("No node found under the cursor! Make sure your cursor is in a list.")
            return
        end

        node = module.required["core.integrations.treesitter"].find_parent(node, "^generic_list$")

        if not node then
            log.error("No list found under the cursor! `toggle-list-type` works only for lists.")
            return
        end

        local first_child = node:iter_children()()

        if not first_child then
            return
        end

        local type = first_child:type():match("^un") and "~" or "-"

        for child in node:iter_children() do
            -- We loop over every subchild because list items may have attached
            -- weak carryover tags which we have to skip.
            for subchild in child:iter_children() do
                if subchild:type():match("_prefix$") then
                    local line, column = subchild:range()

                    vim.api.nvim_buf_set_text(event.buffer, line, column, line, column + 1, { type })

                    break
                end
            end
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.pivot.toggle-list-type"] = true,
    },
}

return module
