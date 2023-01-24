--[[
--
--]]

local neorg = require("neorg.core")
local module = neorg.modules.create("core.itero")

module.setup = function()
    return {
        requires = {
            "core.keybinds",
            "core.integrations.treesitter",
        },
    }
end

module.config.public = {
    -- A list of strings detailing what nodes can be "iterated".
    -- Usually doesn't need to be changed, unless you want to disable some
    -- items from being iterable.
    iterables = {
        "unordered_list%d",
        "ordered_list%d",
        "heading%d",
        "quote%d",
    },

    -- Which items to retain extensions for
    retain_extensions = {
        ["unordered_list%d"] = true,
        ["ordered_list%d"] = true,
    },
}

module.config.private = {
    stop_types = {
        "generic_list",
        "quote",
    },
}

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, { "next-iteration", "stop-iteration" })
end

module.on_event = function(event)
    if event.split_type[2] == (module.name .. ".next-iteration") then
        local ts = module.required["core.integrations.treesitter"]
        local cursor_pos = event.cursor_position[1] - 1

        local current = ts.get_first_node_on_line(event.buffer, cursor_pos, module.config.private.stop_types)

        if not current then
            neorg.log.error(
                "Treesitter seems to be high and can't properly grab the node under the cursor. Perhaps try again?"
            )
            return
        end

        while current:parent() do
            if
                neorg.lib.filter(module.config.public.iterables, function(_, iterable)
                    return current:type():match(table.concat({ "^", iterable, "$" })) and iterable or nil
                end)
            then
                break
            end

            current = current:parent()
        end

        if not current or current:type() == "document" then
            vim.notify("No object to continue! Make sure you're under a list item.")
            return
        end

        local should_append_extension = neorg.lib.filter(
            module.config.public.retain_extensions,
            function(match, should_append)
                return current:type():match(match) and should_append or nil
            end
        ) and current:named_child(1) and current:named_child(1):type() == "detached_modifier_extension"

        local text_to_repeat = ts.get_node_text(current:named_child(0), event.buffer)

        vim.api.nvim_buf_set_lines(
            event.buffer,
            cursor_pos + 1,
            cursor_pos + 1,
            true,
            { text_to_repeat .. (should_append_extension and "( ) " or "") }
        )
        vim.api.nvim_win_set_cursor(
            event.window,
            { cursor_pos + 2, text_to_repeat:len() + (should_append_extension and ("( ) "):len() or 0) }
        )
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".next-iteration"] = true,
        [module.name .. ".stop-iteration"] = true,
    },
}

return module
