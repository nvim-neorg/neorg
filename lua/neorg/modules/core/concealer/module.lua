--[[
    file: Concealer
    title: Display Markup as Icons, not Text
    description: The concealer module converts verbose markup elements into beautified icons for your viewing pleasure.
    summary: Enhances the basic Neorg experience by using icons instead of text.
    embed: https://user-images.githubusercontent.com/76052559/216767027-726b451d-6da1-4d09-8fa4-d08ec4f93f54.png
    ---
"Concealing" is the process of hiding away from plain sight. When writing raw Norg, long strings like
`***** Hello` or `$$ Definition` can be distracting and sometimes unpleasant when sifting through large notes.

To reduce the amount of cognitive load required to "parse" Norg documents with your own eyes, this module
masks, or sometimes completely hides many categories of markup.
--]]

-- utils copied from promo, to be refactored

local function is_prefix_node(node)
    return node:type():match("_prefix$") ~= nil or node:type():match("^link_target_heading") ~= nil
end

local function get_prefix_position_and_level(buffer, prefix_node)
    assert(is_prefix_node(prefix_node), prefix_node:type())
    local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = prefix_node:range()

    assert(row_start_0b == row_end_0bin)
    assert(col_start_0b + 2 <= col_end_0bex)
    local past_end_pos = vim.treesitter.get_node_text(prefix_node, buffer):find(" ") or (col_end_0bex - col_start_0b)
    return row_start_0b, col_start_0b, (past_end_pos - 1)
end

local function get_header_prefix_node(header_node)
    local first_child = header_node:child(0)
    assert(first_child:type() == header_node:type() .. "_prefix")
    return first_child
end

local function get_line_length(buffer, row_0b)
    return vim.api.nvim_strwidth(vim.api.nvim_buf_get_lines(buffer, row_0b, row_0b+1, true)[1])
end

local function table_set_default(tbl, k, v)
    tbl[k] = tbl[k] or v
    return tbl[k]
end

local function table_add_number(tbl, k, v)
    tbl[k] = tbl[k] + v
end

local function table_iclear(tbl)
    for i = #tbl,1,-1 do
        tbl[i] = nil
    end
end

local function table_ifind_first(tbl, pred, from)
    for i = #tbl, (from or 1), -1 do
        if not pred(tbl[i]) then
            return i+1
        end
    end
    return 1
end

local function table_remove_interval(tbl, il, ir_ex)
    assert(0 <= il)
    assert(il <= ir_ex)
    assert(ir_ex <= #tbl + 1)

    if il == ir_ex then
        return
    end

    table.move(tbl, ir_ex, #tbl, il)

    for i = il, ir_ex-1 do
        tbl[#tbl] = nil
    end
end

local function logging(tag, ...)
    do return end
    local func_name = debug.getinfo(2, "n")["name"]
    local n_arg = select("#", ...)
    local args = {...}
    for i = 1,n_arg do
        args[i] = tostring(args[i])
    end
    print('[logging]', tag, func_name.."("..table.concat(args,", ")..")")
end

local function table_tostring_shallow(tbl)
    local args = {}
    for k,v in pairs(tbl) do
        table.insert(args, k .. '=' .. tostring(v))
    end
    return table.concat(args, ", ")
end

local function logging_named(tag, tbl)
    local args = {}
    for k,v in pairs(tbl) do
        table.insert(args, k .. '=' .. tostring(v))
    end
    return logging(tag, table_tostring_shallow(tbl))
end

--- end utils

require("neorg.modules.base")
require("neorg.external.helpers")

local module = neorg.modules.create("core.concealer")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.autocommands",
            "core.integrations.treesitter",
        },
        imports = {
            "preset_basic",
            "preset_varied",
            "preset_diamond",
        },
    }
end

module.private = {
    icon_namespace = vim.api.nvim_create_namespace("neorg-conceals"),
    rerendering_scheduled = false,
    enabled = true,
}

---@class core.concealer
module.public = {
}

module.config.public = {
    icon_preset = "basic",
}

local current_viewport = nil



local prettify_icon_table = {
    numeric           = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    numeric_dot       = { "⒈", "⒉", "⒊", "⒋", "⒌", "⒍", "⒎", "⒏", "⒐", "⒑", "⒒", "⒓", "⒔", "⒕", "⒖", "⒗", "⒘", "⒙", "⒚", "⒛" },
    numeric_pareneses = { "⑴", "⑵", "⑶", "⑷", "⑸", "⑹", "⑺", "⑻", "⑼", "⑽", "⑾", "⑿", "⒀", "⒁", "⒂", "⒃", "⒄", "⒅", "⒆", "⒇" },
    numeric_circled   = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩", "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳" },
    latin_lowercase             = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" },
    latin_uppercase             = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" },
    latin_lowercase_parentheses = { "⒜", "⒝", "⒞", "⒟", "⒠", "⒡", "⒢", "⒣", "⒤", "⒥", "⒦", "⒧", "⒨", "⒩", "⒪", "⒫", "⒬", "⒭", "⒮", "⒯", "⒰", "⒱", "⒲", "⒳", "⒴", "⒵" },
    latin_uppercase_circled     = { "Ⓐ", "Ⓑ", "Ⓒ", "Ⓓ", "Ⓔ", "Ⓕ", "Ⓖ", "Ⓗ", "Ⓘ", "Ⓙ", "Ⓚ", "Ⓛ", "Ⓜ", "Ⓝ", "Ⓞ", "Ⓟ", "Ⓠ", "Ⓡ", "Ⓢ", "Ⓣ", "Ⓤ", "Ⓥ", "Ⓦ", "Ⓧ", "Ⓨ", "Ⓩ" },
    latin_lowercase_circled     = { "ⓐ", "ⓑ", "ⓒ", "ⓓ", "ⓔ", "ⓕ", "ⓖ", "ⓗ", "ⓘ", "ⓙ", "ⓚ", "ⓛ", "ⓜ", "ⓝ", "ⓞ", "ⓟ", "ⓠ", "ⓡ", "ⓢ", "ⓣ", "ⓤ", "ⓥ", "ⓦ", "ⓧ", "ⓨ", "ⓩ" },
}

local operations_of_buf = {}


local function get_prefix_level(buffer, prefix_node)
    return select(3, get_prefix_position_and_level(buffer, prefix_node))
end

local function get_ordered_index(buffer, prefix_node)
    -- TODO: calculate levels in one pass, since treesitter API implementation seems to have ridiculously high complexity
    local level = get_prefix_level(buffer, prefix_node)
    local header_node = prefix_node:parent()
    assert(header_node:type() .. "_prefix" == prefix_node:type())
    local sibling = header_node:prev_named_sibling()
    local count = 1

    while sibling and (sibling:type() == header_node:type()) do
        local sibling_level = get_prefix_level(buffer, get_header_prefix_node(sibling))
        if sibling_level<level then
            break
        elseif sibling_level==level then
            count = count + 1
        end
        sibling = sibling:prev_named_sibling()
    end

    return count, (sibling or header_node:parent())
end

local function get_ordered_icon(icon_table, buffer, prefix_node)
    local index = get_ordered_index(buffer, prefix_node)
    local level = get_prefix_level(buffer, prefix_node)
    local indent = (" "):rep(level - 1)
    local number_icon = icon_table[index] or "~"
    return indent .. number_icon
end

local function get_quote_icon(buffer, node)
    local level = node:type():match("^quote(%d)_prefix$")
    assert(level)
    local row_start_0b, col_start_0b, _row_end_0bin, _col_end_0bex = node:range()
    assert(row_start_0b == _row_end_0bin)
    local icon = "|"
    local texts = {}
    for i = 1,level do
        table.insert(texts, { row_start_0b, col_start_0b+(i-1), icon, "@neorg.quotes."..i..".prefix" })
    end
    return texts
end

pretty_texts = {
    todo_item_done      = { icon = "", },
    todo_item_pending   = { icon = "", },
    todo_item_undone    = { icon = "×", },
    todo_item_uncertain = { icon = "", },
    todo_item_on_hold   = { icon = "", },
    todo_item_cancelled = { icon = "", },
    todo_item_recurring = { icon = "↺", },
    todo_item_urgent    = { icon = "⚠", },

    heading1_prefix = { icon = "◉", highlight = "@neorg.headings.1.prefix", },
    heading2_prefix = { icon = " ◎", highlight = "@neorg.headings.2.prefix", },
    heading3_prefix = { icon = "  ○", highlight = "@neorg.headings.3.prefix", },
    heading4_prefix = { icon = "   ✺", highlight = "@neorg.headings.4.prefix", },
    heading5_prefix = { icon = "    ▶", highlight = "@neorg.headings.5.prefix", },
    heading6_prefix = {
        icon = function(buffer, node) return (" "):rep(get_prefix_level(buffer, node) - 1) .. "⤷" end,
        highlight = "@neorg.headings.6.prefix",
    },

    single_definition_prefix = { icon = "≡" },
    multi_definition_prefix = { icon = "⋙ " },
    multi_definition_suffix = { icon = "⋘ " },

    single_footnote_prefix = { icon = "⁎" },
    multi_footnote_prefix = { icon = "⁑ " },
    multi_footnote_suffix = { icon = "⁑ " },

    -- TODO: delimiter
    spoiler = {
        -- FIXME: multiilne spoiler
        highlight = "@neorg.markup.spoiler",
        icon = function(buffer, node)
            local highlight = pretty_texts.spoiler.highlight
            local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()
            local extmarks = {}
            for i = row_start_0b, row_end_0bin do
                local l = i==row_start_0b and col_start_0b+1 or 0
                local r_ex = i==row_end_0bin and col_end_0bex-1 or get_line_length(buffer, i)
                table.insert(extmarks, {i, l, ("•"):rep(r_ex-l), highlight})
            end
            return extmarks
        end,
    },

    quote1_prefix = { icon = get_quote_icon },
    quote2_prefix = { icon = get_quote_icon },
    quote3_prefix = { icon = get_quote_icon },
    quote4_prefix = { icon = get_quote_icon },
    quote5_prefix = { icon = get_quote_icon },
    quote6_prefix = { icon = get_quote_icon },

    unordered_list1_prefix = { icon = "•", },
    unordered_list2_prefix = { icon = " •", },
    unordered_list3_prefix = { icon = "  •", },
    unordered_list4_prefix = { icon = "   •", },
    unordered_list5_prefix = { icon = "    •", },
    unordered_list6_prefix = {
        icon = function(buffer, node) return (" "):rep(get_prefix_level(buffer, node) - 1) .. "•" end,
    },

    ordered_list1_prefix = {
        icon = function(...) return get_ordered_icon(prettify_icon_table.numeric_dot, ...) end
    },

    ordered_list2_prefix = {
        icon = function(...) return get_ordered_icon(prettify_icon_table.latin_uppercase, ...) end
    },

    ordered_list3_prefix = {
        icon = function(...) return get_ordered_icon(prettify_icon_table.latin_lowercase, ...) end
    },

    ordered_list4_prefix = {
        icon = function(...) return get_ordered_icon(prettify_icon_table.numeric_pareneses, ...) end
    },

    ordered_list5_prefix = {
        icon = function(...) return get_ordered_icon(prettify_icon_table.latin_uppercase, ...) end
    },

    ordered_list6_prefix = {
        icon = function(buffer, node)
            local level = get_prefix_level(buffer, node)
            local icon_tables = {
                prettify_icon_table.latin_lowercase_parentheses,
                prettify_icon_table.latin_uppercase_circled,
                prettify_icon_table.latin_lowercase_circled,
                prettify_icon_table.numeric_circled,
                prettify_icon_table.numeric,
            }
            local the_icon_table = icon_tables[level-6+1] or icon_tables[#icon_tables]
            return get_ordered_icon(the_icon_table, buffer, node)
        end
    },

    ranged_verbatim_tag = {
        icon = function(buffer, node)
            local highlight = "@neorg.tags.ranged_verbatim.code_block" 
            local row_start_0b, _col_start_0b, row_end_0bin, _col_end_0bex = node:range()
            local texts = {}
            for i = row_start_0b, row_end_0bin do
                table.insert(texts, { i, 0, "", highlight})
            end
            return texts, { hl_eol = true, hl_group = highlight }
        end
    }
}

local function checked_gsub(...)
    local result, n_match = string.gsub(...)
    assert(0 <= n_match)
    assert(n_match <= 1)
    assert(result)
    if n_match==1 then
        return result
    end
end

config_name_dict = {
    heading = function(key) return checked_gsub(key, "^level_(%d+)$", "heading%1_prefix") end,
    todo = function(key) return checked_gsub(key, "^%w+$", "todo_item_%0") end,
    list = function(key) return checked_gsub(key, "^level_(%d+)$", "unordered_list%1_prefix") end,
    ordered = function(key) return checked_gsub(key, "^level_(%d+)$", "ordered_list%1_prefix") end,
    quote = function(key) return checked_gsub(key, "^quote_(%d+)$", "quote%1_prefix") end,
    definition = {
        single = "single_definition_prefix",
        multi_prefix = "multi_definition_prefix",
        multi_suffix = "multi_definition_suffix",
    },
    delimiter = {
        weak = "weak_paragraph_delimiter",
        strong = "strong_paragraph_delimiter",
        horizontal_line = "horizontal_line",
    },
    footnote = {
        single = "single_footnote_prefix",
        multi_prefix = "multi_footnote_prefix",
        multi_suffix = "multi_footnote_suffix",
    },
    markup = {
        spoiler = "spoiler",
    },
}


local function table_extend_in_place(tbl, tbl_ext)
    for k,v in pairs(tbl_ext) do
        tbl[k] = v
    end
end

local function link_target_heading_before_description(node)
    local sibling = node:parent():next_named_sibling()
    return sibling and sibling:type() == "link_description"
    -- BUG found: 190-219
end

table_extend_in_place(pretty_texts, {
    link_target_heading1 = vim.tbl_extend("error", pretty_texts.heading1_prefix, { check_conceal = link_target_heading_before_description }),
    link_target_heading2 = vim.tbl_extend("error", pretty_texts.heading2_prefix, { check_conceal = link_target_heading_before_description }),
    link_target_heading3 = vim.tbl_extend("error", pretty_texts.heading3_prefix, { check_conceal = link_target_heading_before_description }),
    link_target_heading4 = vim.tbl_extend("error", pretty_texts.heading4_prefix, { check_conceal = link_target_heading_before_description }),
    link_target_heading5 = vim.tbl_extend("error", pretty_texts.heading5_prefix, { check_conceal = link_target_heading_before_description }),
    link_target_heading6 = vim.tbl_extend("error", pretty_texts.heading6_prefix, { check_conceal = link_target_heading_before_description }),

    link_target_definition = vim.tbl_extend("error", pretty_texts.single_definition_prefix, { conceal = true }),
    link_target_footnote = vim.tbl_extend("error", pretty_texts.single_footnote_prefix, { conceal = true }),
    -- TODO: link, definition, footnote, 
})

local function pos_le(pos1, pos2)
    return pos1.x < pos2.x or (pos1.x == pos2.x and pos1.y <= pos2.y)
end

local function pos_lt(pos1, pos2)
    return pos1.x < pos2.x or (pos1.x == pos2.x and pos1.y < pos2.y)
end

local function remove_extmarks(buffer, pos_start_0b_0b, pos_end_0bin_0bex)
    print('%%% remove_extmarks', vim.inspect(pos_start_0b_0b), vim.inspect(pos_end_0bin_0bex))
    assert(pos_start_0b_0b.x <= pos_end_0bin_0bex.x)
    local icon_namespace = module.private.icon_namespace
    for _, result in ipairs(vim.api.nvim_buf_get_extmarks(buffer, icon_namespace, {pos_start_0b_0b.x, pos_start_0b_0b.y}, {pos_end_0bin_0bex.x, pos_end_0bin_0bex.y-1}, {})) do
        local extmark_id = result[1]
        local node_pos_0b_0b = { x = result[2], y = result[3] }
        assert(pos_le(pos_start_0b_0b, node_pos_0b_0b) and pos_lt(node_pos_0b_0b, pos_end_0bin_0bex), ("start=%s, end=%s, node=%s"):format(vim.inspect(pos_start_0b_0b), vim.inspect(pos_end_0bin_0bex), vim.inspect(node_pos_0b_0b)))
        vim.api.nvim_buf_del_extmark(buffer, icon_namespace, extmark_id)
    end
end

local function in_range(k, l, r_ex)
    return l<=k and k<r_ex
end

local function is_inside_example(node)
    -- TODO: waiting for parser fix
    return false
end

local function should_skip_prettify(mode, current_row_0b, node, row_start_0b, row_end_0bex)
    local result
    if (mode == "i") and in_range(current_row_0b, row_start_0b, row_end_0bex) then
        result = true
    elseif is_inside_example(node) then
        result = true
    else
        result = false
    end
    -- print('@@@@@@@ should_skip_prettify =', result, mode, current_row_0b, node, row_start_0b, row_end_0bex, '.')
    return result
end

local function is_concealing_on_row_range(mode, conceallevel, concealcursor, current_row_0b, row_start_0b, row_end_0bex)
    if conceallevel<1 then
        return false
    elseif not in_range(current_row_0b, row_start_0b, row_end_0bex) then
        return true
    else
        return (concealcursor:find(mode) ~= nil)
    end
end

local function query_get_nodes(query, document_root, buffer, row_start_0b, row_end_0bex)
    local result = {}
    for _id, node, _metadata in query:iter_captures(document_root, buffer, row_start_0b, row_end_0bex) do
        table.insert(result, node)
    end
    return result
end

local function get_node_row_start(node)
    return (node:start())
end

local function get_node_row_end(node)
    return (node:end_())
end

local function check_min(xy, x_new, y_new)
    if (x_new < xy.x) or (x_new == xy.x and y_new < xy.y) then
        xy.x = x_new
        xy.y = y_new
    end
end

local function check_max(xy, x_new, y_new)
    if (x_new > xy.x) or (x_new == xy.x and y_new > xy.y) then
        xy.x = x_new
        xy.y = y_new
    end
end

local function to_xy(x, y)
    return { x = x, y = y }
end

local function prettify_range(buffer, row_start_0b, row_end_0bex)
    -- in case there's undo/removal garbage
    -- TODO: optimize
    row_end_0bex = math.min(row_end_0bex + 1, vim.api.nvim_buf_line_count(buffer))

    local treesitter_module = module.required["core.integrations.treesitter"]
    local document_root = treesitter_module.get_document_root(buffer)
    local nodes = query_get_nodes(prettify_query, document_root, buffer, row_start_0b, row_end_0bex)

    local pos_start_0b_0b = { x = row_start_0b, y = 0 }
    local pos_end_0bin_0bex = { x = row_end_0bex-1, y = get_line_length(buffer, row_end_0bex-1) }

    for i = 1, #nodes do
        check_min(pos_start_0b_0b, nodes[i]:start())
        check_max(pos_end_0bin_0bex, nodes[i]:end_())
    end

    remove_extmarks(buffer, pos_start_0b_0b, pos_end_0bin_0bex)

    local current_row_0b = vim.api.nvim_win_get_cursor(0)[1] - 1
    local current_mode = vim.api.nvim_get_mode().mode
    local conceallevel = vim.wo.conceallevel
    local concealcursor = vim.wo.concealcursor
    local icon_namespace = module.private.icon_namespace

    assert(document_root)

    for _, node in ipairs(nodes) do
        -- FIXME skip prettify
        local node_row_start_0b, node_col_start_0b, _node_row_end_0bin, _node_col_end_0bex = node:range()
        local node_row_end_0bex = _node_row_end_0bin + 1

        if should_skip_prettify(current_mode, current_row_0b, node, node_row_start_0b, node_row_end_0bex) then
            goto continue
        end

        local text = pretty_texts[node:type()]
        assert(text)
        local has_conceal = text.check_conceal and text.check_conceal(node) and is_concealing_on_row_range(current_mode, conceallevel, concealcursor, current_row_0b, node_row_start_0b, node_row_end_0bex)
        if has_conceal then
            goto continue
        end
        local texts, ext_opts
        if type(text.icon)=="string" then
            texts = {{ node_row_start_0b, node_col_start_0b, text.icon, text.highlight}}
        else
            texts, ext_opts = text.icon(buffer, node)
            if type(texts) == "string" then
                texts = {{ node_row_start_0b, node_col_start_0b, texts, text.highlight }}
            end
        end

        for i = 1, #texts do
            local r_0b = texts[i][1]
            local c_0b = texts[i][2]
            local virt_text = texts[i][3]
            local highlight = texts[i][4]
            local opt = {
                virt_text=virt_text and {{virt_text, highlight}},
                virt_text_pos="overlay",
                virt_text_win_col=nil, --c_0b,
                hl_group=nil,
                conceal=nil,
                id=nil,
                end_row=r_0b,
                end_col=c_0b,
                hl_eol=nil,
                virt_text_hide=nil,
                hl_mode="combine",
                virt_lines=nil,
                virt_lines_above=nil,
                virt_lines_leftcol=nil,
                ephemeral=nil,
                right_gravity=nil,
                end_right_gravity=nil,
                priority=nil,
                strict=nil, -- default true
                sign_text=nil,
                sign_hl_group=nil,
                number_hl_group=nil,
                line_hl_group=nil,
                cursorline_hl_group=nil,
                spell=nil,
                ui_watched=nil,
            }
            if ext_opts then
                opt = vim.tbl_extend("error", opt, ext_opts)
            end
            local id = vim.api.nvim_buf_set_extmark(buffer, icon_namespace, r_0b, c_0b, opt)
        end
        ::continue::
    end
end

local function do_operations_for_buffer(buffer, operations)
    assert(not vim.tbl_isempty(operations))
    --regenerate_full(buffer)

    -- invariant:
    -- 0 <= itv.l <= itv.r_ex  forall itv
    -- itv.r_ex < itv'.l   forall adjacent itv and itv'
    local changed_intervals = {}

    for _, op in ipairs(operations) do
        local il = table_ifind_first(changed_intervals, function(itv) return op.row_start_0b <= itv.l end)
        local ir = table_ifind_first(changed_intervals, function(itv) return op.row_end_old_0bex < itv.l end, l)

        if il>1 and op.row_start_0b <= changed_intervals[il-1].r_ex then
            il = il - 1
        elseif il==ir then
            table.insert(changed_intervals, il, { l = op.row_start_0b, r_ex = op.row_end_old_0bex })
            ir = ir + 1
        else
            assert(op.row_start_0b <= changed_intervals[il].l)
            changed_intervals[il].l = op.row_start_0b
        end
        changed_intervals[il].r_ex = math.max(op.row_end_old_0bex, changed_intervals[ir-1].r_ex)
        table_remove_interval(changed_intervals, il+1, ir)
        local end_diff = op.row_end_new_0bex - op.row_end_old_0bex
        if end_diff ~= 0 then
            for i = il, #changed_intervals do
                changed_intervals[i].r_ex = changed_intervals[i].r_ex + end_diff
                assert(changed_intervals[i].l <= changed_intervals[i].r_ex)
                assert(i == il or (changed_intervals[i].l < changed_intervals[i].r_ex))
            end
        end
    end

    assert(not vim.tbl_isempty(changed_intervals))
    local overall_l = changed_intervals[1].l
    local overall_r_ex = changed_intervals[#changed_intervals].r_ex
    local n_buf_line = vim.api.nvim_buf_line_count(buffer)
    assert(0 <= overall_l, ("overall_l=%s"):format(overall_l))
    assert(overall_l <= overall_r_ex)
    -- assert(overall_r_ex <= n_buf_line, ("overall_r_ex=%s, n_buf_line=%s"):format(overall_r_ex, n_buf_line))
    overall_r_ex = math.min(overall_r_ex, n_buf_line)
    prettify_range(buffer, overall_l, overall_r_ex)
end

local function do_operations_for_all_buffers()
    -- local old_lazyredraw = vim.go.lazyredraw
    -- vim.go.lazyredraw = true
    for buffer, operations in pairs(operations_of_buf) do
        do_operations_for_buffer(buffer, operations)
        --table_iclear(operations)
    end
    operations_of_buf = {}
    -- vim.go.lazyredraw = old_lazyredraw
    module.private.rerendering_scheduled = false
end

local function add_operation(buffer, op)
    local operations = operations_of_buf[buffer]
    if operations == nil then
        operations = {}
        operations_of_buf[buffer] = operations
    end

    table.insert(operations, op)
    if not module.private.rerendering_scheduled then
        module.private.rerendering_scheduled = true
        vim.schedule(do_operations_for_all_buffers)
    end
end

local function add_operation_whole_buffer(buffer)
    local line_count = vim.api.nvim_buf_line_count(buffer)
    add_operation(buffer, {row_start_0b = 0, row_end_old_0bex = line_count, row_end_new_0bex = line_count})
end

local function handle_bufread(event)
    assert(vim.api.nvim_win_is_valid(event.window))

    local function on_bytes_callback(_tag, buffer, _changedtick, row_start_0b, col_start_0b, byte_offset, old_row_end_0bex, old_col_end_0bex, old_byte_changed, new_row_end_0bex, new_col_end_0bex, new_byte_changed)
        assert(_tag == "bytes")
        print(("@@@@ on_byte, start=(%s,%s), byte_offset=%s, old_end=(%s,%s):%s, new_end=(%s,%s):%s"):format(
        row_start_0b, col_start_0b, byte_offset, old_row_end_0bex, old_col_end_0bex, old_byte_changed, new_row_end_0bex, new_col_end_0bex, new_byte_changed))
    end

    local function on_line_callback(_tag, buffer, _changedtick, row_start_0b, row_end_0bex, row_updated_0bex, n_byte_prev)
        assert(_tag == "lines")
        print(("@@@@' on_line, row_start_0b=%s, row_end=%s, row_updated=%s, n_byte_prev=%s"):format(row_start_0b, row_end_0bex, row_updated_0bex, n_byte_prev))
        add_operation(buffer, {row_start_0b = row_start_0b, row_end_old_0bex = row_end_0bex, row_end_new_0bex = row_updated_0bex})
    end

    local attach_succeeded = vim.api.nvim_buf_attach(event.buffer, true, { on_lines = on_line_callback })
    assert(attach_succeeded)
    local language_tree = vim.treesitter.get_parser(event.buffer, 'norg')

    local buffer = event.buffer
    -- used for detecting non-local (multiline) changes, like spoiler / code block
    -- TODO: exemption in certain cases, for example when changing only heading followed by pure texts,
    -- in which case all its descendents would be unnecessarily re-concealed.
    local function on_changedtree_callback(ranges)
        -- TODO: abandon if too large
        print(("@@@@' on_changedtree, ranges=%s"):format(vim.inspect(ranges)))
        for i = 1, #ranges do
            local range = ranges[i]
            add_operation(buffer, { row_start_0b=range[1], row_end_old_0bex=range[3]+1, row_end_new_0bex=range[3]+1 })
        end
    end

    language_tree:register_cbs({ on_changedtree = on_changedtree_callback })

    --add_operation(event.buffer, {row_start_0b = 0, row_end_old_0bex = 0, row_end_new_0bex = vim.api.nvim_buf_line_count(event.buffer)})
    add_operation_whole_buffer(event.buffer)
end

local function add_operation_at_row(buffer, row_0b)
    add_operation(buffer, {row_start_0b = row_0b, row_end_old_0bex = row_0b+1, row_end_new_0bex = row_0b+1})
end

local function handle_insert_toggle(event)
    add_operation_at_row(event.buffer, event.cursor_position[1]-1)
end

local function handle_insertenter(event)
    print('$$$ insertenter', vim.inspect(event))
    handle_insert_toggle(event)
end

local function handle_insertleave(event)
    print('$$$ insertleave', vim.inspect(event))
    handle_insert_toggle(event)
end

local function handle_update_region(event)
    -- print('@@ handle_update_region')
end

local function handle_toggle_prettifier(event)
    module.private.enabled = not module.private.enabled
    if module.private.enabled then
        add_operation_whole_buffer(event.buffer)
    else
        local icon_namespace = module.private.icon_namespace
        vim.api.nvim_buf_clear_namespace(0, icon_namespace, 0, -1)
    end
end

cursor_record = nil
-- TODO: multiple buffer

local function is_same_line_movement(event)
    -- some operations like dd / u cannot yet be listened reliably
    -- below is our best approximation
    return (cursor_record
      and cursor_record.row_0b == event.cursor_position[1]-1
      and cursor_record.col_0b ~= event.cursor_position[2]
      and cursor_record.line_content == event.line_content)
end

local function update_cursor(event)
    if not cursor_record then
        cursor_record = {}
    end
    cursor_record.row_0b = event.cursor_position[1] - 1
    cursor_record.col_0b = event.cursor_position[2]
    cursor_record.line_content = event.line_content
end

local function handle_cursor_moved(event)
    local current_row_0b = event.cursor_position[1] - 1
    -- reveal/conceal when conceallevel>0
    -- also triggered when dd / u
    if not is_same_line_movement(event) then
        if cursor_record then
            add_operation_at_row(event.buffer, cursor_record.row_0b)
        end
        -- TODO: make sure last_cursor_row_0b is not nil
        add_operation_at_row(event.buffer, current_row_0b)
    end
    update_cursor(event)
end

local function handle_cursor_moved_i(event)
    return handle_cursor_moved(event)
end

local event_handlers = {
    ["core.neorgcmd.events.core.concealer.toggle"] = handle_toggle_prettifier,
    ["core.autocommands.events.bufread"] = handle_bufread,
    ["core.autocommands.events.insertenter"] = handle_insertenter,
    ["core.autocommands.events.insertleave"] = handle_insertleave,
    ["core.autocommands.events.cursormoved"] = handle_cursor_moved,
    ["core.autocommands.events.cursormovedi"] = handle_cursor_moved_i,
}

module.on_event = function(event)
    if not event.content.norg then
        -- TODO: move to on_event?
        return
    end

    print(vim.inspect(event))
    if (not module.private.enabled) and (event.type ~= "core.neorgcmd.events.core.concealer.toggle") then
        return
    end
    return event_handlers[event.type](event)
end

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufRead")
    module.required["core.autocommands"].enable_autocommand("InsertEnter")
    module.required["core.autocommands"].enable_autocommand("InsertLeave")
    module.required["core.autocommands"].enable_autocommand("CursorMoved")
    module.required["core.autocommands"].enable_autocommand("CursorMovedI")

    neorg.modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            ["toggle-concealer"] = {
                name = "core.concealer.toggle",
                args = 0,
                condition = "norg",
            },
        })
    end)
    if neorg.utils.is_minimum_version(0, 7, 0) then
        vim.api.nvim_create_autocmd("OptionSet", {
            pattern = "conceallevel",
            callback = function()
                local current_buffer = vim.api.nvim_get_current_buf()
                if vim.bo[current_buffer].ft ~= "norg" then
                    return
                end
                add_operation_whole_buffer(current_buffer)
            end,
        })
    end

    -- compile treesitter query
    local builder = {"["}
    for node_type, cfg in pairs(pretty_texts) do
        table.insert(builder, cfg.query or ("(" .. node_type .. ")@icon"))
    end
    table.insert(builder, "]")
    local query_string = table.concat(builder)
    prettify_query = neorg.utils.ts_parse_query("norg", query_string)
end


-- TODO;
-- [x] lazyredraw, ttyfast
-- [x] no conceal on cursor line at insert mode
-- [---------] no conceal inside examples
-- [x] insert mode movement
-- [x] code, spoiler, non-local changes, languagetree (WONTFIX complicated cases)
-- [ ]code config
-- [x] conceal links
-- [x] fix toggle-concealer
-- [ ] visual mode skip prettify ("ivV"):find(mode), ModeChanged
-- [+++++++] use vim.b[bufnr]
-- [ ] chuncked concealing on demand for large file
-- --- (prev), current, (next): singleton record, changed when moving large steps
-- [ ] adaptive performance tuning: instant, CursorHold
-- [ ] multi-column ordering
-- number_spec: "§A.a1."
-- digit_infos: { ["A"] = ..., ["a"] = ..., ["1"] = ..., ["⑴"] = ... }
-- result: render({3,5,2,6,7}) = "§C.e2.6.7"
-- folding

module.events.defined = {
    -- update_region = neorg.events.define(module, "update_region"),
}

module.events.subscribed = {
    ["core.autocommands"] = {
        bufread = true,
        insertenter = true,
        insertleave = true,
        vimleavepre = true,
        cursormoved = true,
        cursormovedi = true,
    },

    ["core.neorgcmd"] = {
        ["core.concealer.toggle"] = true,
    },

    ["core.concealer"] = {
        -- update_region = true,
    },
}

return module
