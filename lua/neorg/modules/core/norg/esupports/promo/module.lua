--[[
-- Module for promoting and demoting headings
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.esupports.promo")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.keybinds",
            "core.integrations.treesitter"
        }
    }
end

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, { "promote", "demote", "promote-recursive", "demote-recursive" })
end

module.config.private = {
}

module.public = {
}

module.on_event = function(event)
    local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

    local function indent_whole_node(node, amount)
        local rs, _, re = node:range()

        local lines = vim.api.nvim_buf_get_lines(event.buffer, rs + 1, re, true)

        for i = 1, #lines do
            lines[i] = (amount >= 0 and (string.rep(" ", amount) .. lines[i]) or lines[i]:sub(-amount + 1))
        end

        vim.api.nvim_buf_set_lines(event.buffer, rs + 1, re, false, lines)
    end

    -- nvim_feedkeys doesn't seem to work with `^` properly
    local old_cursor_pos = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_set_cursor(event.window, { old_cursor_pos[1], event.line_content:match("^%s*"):len() })

    local node_at_cursor = ts_utils.get_node_at_cursor(event.window, true)

    local rs, cs, re, ce = node_at_cursor:range()
    local text = module.required["core.integrations.treesitter"].get_node_text(node_at_cursor)

    if not node_at_cursor:type():match("^.+_prefix$") then
        local parent = module.required["core.integrations.treesitter"].find_parent(node_at_cursor, "^paragraph$") or node_at_cursor

        if parent:prev_named_sibling() and parent:prev_named_sibling():type():match("^.+_prefix$") then
            node_at_cursor = parent:prev_named_sibling()
            rs, cs, re, ce = node_at_cursor:range()
            text = module.required["core.integrations.treesitter"].get_node_text(node_at_cursor)
        else
            vim.api.nvim_feedkeys(event.type:find("promote") and ">>" or "<<", "n", true)
            goto skip
        end
    end

    if not text then
        goto skip
    end

    if event.type == "core.keybinds.events.core.norg.esupports.promo.promote" then
        vim.api.nvim_buf_set_text(event.buffer, rs, cs, re, ce, { text:sub(1, 1) .. text })

        -- HACK(vhyrro): Sometimes for whatever reason `node_at_cursor:parent()` returns
        -- the exact same node as `node_at_cursor`.
        if vim.endswith(node_at_cursor:parent():type(), "_prefix") then
            node_at_cursor = node_at_cursor:parent()
        end

        indent_whole_node(node_at_cursor:parent(), 1)
    elseif event.type == "core.keybinds.events.core.norg.esupports.promo.demote" then
        if text:match("[^%s]*"):len() == 1 then
            vim.api.nvim_echo({{ "Cannot demote any further!" }}, false, {})
            goto skip
        end

        -- HACK(vhyrro): See comment in previous if branch
        if vim.endswith(node_at_cursor:parent():type(), "_prefix") then
            node_at_cursor = node_at_cursor:parent()
        end

        vim.api.nvim_buf_set_text(event.buffer, rs, cs, re, ce, { text:sub(2) })
        indent_whole_node(node_at_cursor:parent(), -1)
    end

    ::skip::
    vim.api.nvim_win_set_cursor(event.window, old_cursor_pos)
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".promote"] = true,
        [module.name .. ".demote"] = true,
        [module.name .. ".promote-recursive"] = true,
        [module.name .. ".demote-recursive"] = true,
    }
}

return module
