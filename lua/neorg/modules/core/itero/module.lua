--[[
    file: Itero
    title: Fast List/Heading Continuation
    description: Fluidness is key, after all.
    summary: Module designed to continue lists, headings and other iterables.
    embed: https://user-images.githubusercontent.com/76052559/216777858-14e2036e-acc5-4276-aa7d-9a8a8ba549ba.gif
    ---
`core.itero` is a rather small and simple module designed to assist in the creation of many lists,
headings and other repeatable (iterable) items.

By default, the key that is used to iterate on an item is `<M-CR>` (Alt + Enter). If you want to
change the bind, remap the `core.itero.next-iteration` event.

Begin by writing an initial item you'd like to iterate (in this instance, and unordered list item):
```md
- Hello World!
```

With your cursor in insert mode at the end of the line, pressing the keybind will continue the item at whatever
nesting level it is currently at (where `|` is the new cursor position):
```md
- Hello World!
- |
```

The same can also be done for headings:
```md
* Heading 1
* |
```

This functionality is commonly paired with the [`core.promo`](@core.promo) module to then indent/dedent
the item under the cursor with the `<C-t>` and `<C-d>` bindings.
--]]

local neorg = require("neorg.core")
local lib, log, modules = neorg.lib, neorg.log, neorg.modules

local module = modules.create("core.itero")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.config.public = {
    -- A list of lua patterns detailing what treesitter nodes can be "iterated".
    -- Usually doesn't need to be changed, unless you want to disable some
    -- items from being iterable.
    iterables = {
        "unordered_list%d",
        "ordered_list%d",
        "heading%d",
        "quote%d",
    },

    -- Which item types to retain extensions for.
    --
    -- If the item you are currently iterating has an extension (e.g. `( )`, `(x)` etc.),
    -- then the following items will also have an extension (by default `( )`) attached
    -- to them automatically.
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
    vim.keymap.set("!", "<Plug>(neorg.itero.next-iteration)", module.public.next_iteration_cr)
end

---@class core.itero
module.public = {
    next_iteration_cr = function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local buffer = vim.api.nvim_get_current_buf()

        local ts = module.required["core.integrations.treesitter"]
        local cursor_pos = cursor[1] - 1

        local current = ts.get_first_node_on_line(buffer, cursor_pos, module.config.private.stop_types)

        if not current then
            log.error(
                "Treesitter seems to be high and can't properly grab the node under the cursor. Perhaps try again?"
            )
            return
        end

        while current:parent() do
            if
                lib.filter(module.config.public.iterables, function(_, iterable)
                    return current:type():match(table.concat({ "^", iterable, "$" })) and iterable or nil
                end)
            then
                break
            end

            current = current:parent()
        end

        if not current or current:type() == "document" then
            vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
            return
        end

        local should_append_extension = lib.filter(
            module.config.public.retain_extensions,
            function(match, should_append)
                return current:type():match(match) and should_append or nil
            end
        ) and current:named_child(1) and current:named_child(1):type() == "detached_modifier_extension"

        local text_to_repeat = ts.get_node_text(current:named_child(0), buffer)

        local _, column = current:start()

        local is_on_nonempty_line = vim.api.nvim_buf_get_lines(buffer, cursor_pos, cursor_pos + 1, true)[1]:match("%S")
        if is_on_nonempty_line then
            cursor_pos = cursor_pos + 1
        end

        vim.api.nvim_buf_set_lines(
            buffer,
            cursor_pos,
            cursor_pos + (is_on_nonempty_line and 0 or 1),
            true,
            { string.rep(" ", column) .. text_to_repeat .. (should_append_extension and "( ) " or "") }
        )
        vim.api.nvim_win_set_cursor(
            0,
            { cursor_pos + 1, column + text_to_repeat:len() + (should_append_extension and ("( ) "):len() or 0) }
        )
    end,
}

return module
