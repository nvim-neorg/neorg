--[[
-- Module for promoting and demoting headings
--]]

-- KNOWN BUGS:
--> Heading that goes over 6 levels does not indent the other levels properly
--> Because of treesitter the AST tends to not update fast enough and as a result
--  promotion does not happen as expected.
--> The concealer breaks when updating a large region fo text (create a concealer
--  update-region event).

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.esupports.promo")

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
    module.required["core.keybinds"].register_keybinds(
        module.name,
        { "promote", "demote", "promote-recursive", "demote-recursive" }
    )
end

module.config.private = {}

module.private = {
    indent_whole_node = function(buffer, node, amount, dont_skip_first_line)
        local rs, cs, re, ce = node:range()

        local lines = vim.api.nvim_buf_get_text(buffer, rs, cs, re, ce, {})

        for i = dont_skip_first_line and 1 or 2, ce == 0 and (#lines - 1) or #lines do
            lines[i] = (amount >= 0 and (string.rep(" ", amount) .. lines[i]) or lines[i]:sub(-amount + 1))
        end

        vim.api.nvim_buf_set_text(buffer, rs, cs, re, ce, lines)
    end,
}

module.public = {
    promote_or_demote = function(node, buffer, window, mode)
        local rs, cs, re, ce = node:range()
        local text = module.required["core.integrations.treesitter"].get_node_text(node)

        if not node:type():match("^.+_prefix$") then
            local parent = module.required["core.integrations.treesitter"].find_parent(node, "^paragraph$") or node

            if parent:prev_named_sibling() and parent:prev_named_sibling():type():match("^.+_prefix$") then
                node = parent:prev_named_sibling()
                rs, cs, re, ce = node:range()
                text = module.required["core.integrations.treesitter"].get_node_text(node)
            else
                vim.api.nvim_feedkeys(mode:find("promote") and ">>" or "<<", "n", true)
                return
            end
        end

        if not text then
            return
        end

        if mode:find("promote") then
            vim.api.nvim_buf_set_text(buffer, rs, cs, re, ce, { text:sub(1, 1) .. text })

            if vim.endswith(mode, "recursive") then
                local match = "^" .. node:parent():type():match("^(.+)%d+") .. "%d+"

                for child_node in node:parent():iter_children() do
                    if module.required["core.integrations.treesitter"].is_node_first_on_line(child_node) then
                        if child_node:type():match(match) then
                            if child_node:named_child(0) then
                                module.public.promote_or_demote(child_node:named_child(0), buffer, window, mode)
                            end
                        else
                            module.private.indent_whole_node(buffer, child_node, 1, true)
                        end
                    end
                end

                local parent_range = { node:parent():range() }

                neorg.events.broadcast_event(neorg.events.create(module, "core.norg.concealer.events.update_region", {
                    start = parent_range[1],
                    ["end"] = parent_range[3],
                }))
            else
                -- NOTE: This should only be done during promotion, as doing it
                -- when demoting gives unintended side effects.
                -- TODO: Document what this even does.
                vim.api.nvim_win_set_cursor(window, { rs + 1, cs + 1 })
                vim.treesitter.get_parser(buffer, "norg"):parse()

                local new_node = module.required["core.integrations.treesitter"]
                    .get_ts_utils()
                    .get_node_at_cursor(window, true)
                    :parent()
                module.private.indent_whole_node(buffer, new_node, 1)
            end
        elseif mode:find("demote") then
            if text:match("[^%s]*"):len() == 1 then
                vim.api.nvim_echo({ { "Cannot demote any further!" } }, false, {})
                return
            end

            -- HACK(vhyrro): Sometimes for whatever reason `node:parent()`
            -- returns the exact same node as just `node`.
            if vim.endswith(node:parent():type(), "_prefix") then
                node = node:parent()
            end

            vim.api.nvim_buf_set_text(buffer, rs, cs, re, ce, { text:sub(2) })
            module.private.indent_whole_node(buffer, node:parent(), -1)
        end
    end,
}

module.on_event = function(event)
    vim.treesitter.get_parser(event.buffer, "norg"):parse()

    local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

    local old_cursor_pos = vim.api.nvim_win_get_cursor(event.window)
    vim.api.nvim_win_set_cursor(event.window, { old_cursor_pos[1], event.line_content:match("^%s*"):len() })

    local node_at_cursor = ts_utils.get_node_at_cursor(event.window, true)

    local mode = neorg.lib.match(event.type)({
        ["core.keybinds.events.core.norg.esupports.promo.promote"] = "promote",
        ["core.keybinds.events.core.norg.esupports.promo.demote"] = "demote",
        ["core.keybinds.events.core.norg.esupports.promo.promote-recursive"] = "promote-recursive",
        ["core.keybinds.events.core.norg.esupports.promo.demote-recursive"] = "demote-recursive",
    })

    module.public.promote_or_demote(node_at_cursor, event.buffer, event.window, mode)

    vim.api.nvim_win_set_cursor(event.window, old_cursor_pos)
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".promote"] = true,
        [module.name .. ".demote"] = true,
        [module.name .. ".promote-recursive"] = true,
        [module.name .. ".demote-recursive"] = true,
    },
}

return module
