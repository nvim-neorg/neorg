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
    -- To be used in the future
    promote_whitelist = {
        "paragraph"
    }
}

module.public = {
    promote = function(node)
        local node_text = module.required["core.integrations.treesitter"].get_node_text(node)
        local prefix = node_text:sub(0, 1)

        local tab = (function()
            if not vim.opt_local.expandtab then
                return "	"
            else
                return string.rep(" ", vim.opt_local.tabstop:get())
            end
        end)()

        if vim.tbl_contains({
            "-",
            "*",
            ">",
            "~",
        }, prefix) then
            return tab .. prefix .. node_text
        end

        return tab .. node_text
    end
}

module.on_event = function(event)
    local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

    local function indent_whole_node(node)
        local rs, _, re = node:range()

        for i = rs + 1, re + 1, 100 do
            vim.schedule(function() vim.cmd(tostring(rs + 1) .. ":normal! 100=j") end)
        end
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
        indent_whole_node(node_at_cursor:parent())
    elseif event.type == "core.keybinds.events.core.norg.esupports.promo.demote" then
        if text:match("[^%s]*"):len() == 1 then
            vim.api.nvim_echo({{ "Cannot demote any further!" }}, false, {})
            goto skip
        end

        vim.api.nvim_buf_set_text(event.buffer, rs, cs, re, ce, { text:sub(2) })
        indent_whole_node(node_at_cursor:parent())
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
