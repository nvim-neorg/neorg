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
    local row_start, col_start, row_end, col_end = prefix_node:range()

    assert(row_start == row_end)
    assert(col_start + 2 <= col_end)
    local past_end_pos = vim.treesitter.get_node_text(prefix_node, buffer):find(" ") or (col_end - col_start)
    return row_start, col_start, (past_end_pos - 1)
end

local function get_header_prefix_node(header_node)
    local first_child = header_node:child(0)
    assert(first_child:type() == header_node:type() .. "_prefix")
    return first_child
end

--- end utils

require("neorg.modules.base")
require("neorg.external.helpers")

local module = neorg.modules.create("core.concealer")

local function table_set_default(tbl, k, v)
    tbl[k] = tbl[k] or v
end

local function table_add_number(tbl, k, v)
    tbl[k] = tbl[k] + v
end

local function buffer_get_line(buffer, row)
    return vim.api.nvim_buf_get_lines(buffer, row, row+1, false)[1] or ""
end

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
}

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

---@class core.concealer
module.public = {
}

module.config.public = {
}

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufRead")
    local builder = {"["}
    for node_type, cfg in pairs(conceal_texts) do
        table.insert(builder, cfg.query or ("(" .. node_type .. ")@icon"))
    end
    table.insert(builder, "]")
    local query_string = table.concat(builder)
    conceal_query = neorg.utils.ts_parse_query("norg", query_string)
end

local function rerender_range(buffer, row_start, row_end)
    row_start = row_start or 0
    row_end = row_end or vim.api.nvim_buf_line_count(buffer)


end

local function handle_insertenter(event)
    -- print('@@ handle_insertenter')
end

local function handle_insertleave(event)
    -- print('@@ handle_insertleave')
end

local function handle_vimleavepre(event)
    -- print('@@ handle_vimleavepre')
end

local function handle_update_region(event)
    -- print('@@ handle_update_region')
end

local function node_text_width(node)
    local row_start, col_start, row_end, col_end = node:range()
    assert(row_start == row_end)
    return col_end - col_start
end

my_namespace = vim.api.nvim_create_namespace("neorg-conceals")

local conceal_icon_table = {
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

    return count
end

local function get_ordered_icon(icon_table, buffer, prefix_node)
    local index = get_ordered_index(buffer, prefix_node)
    local level = get_prefix_level(buffer, prefix_node)
    local indent = (" "):rep(level - 1)
    local number_icon = icon_table[index] or "~"
    print(number_icon, level)
    return indent .. number_icon
end

conceal_texts = {
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

    -- TODO: definition, footnote, delimiter, markup, quote
    spoiler = {
        -- query = '(spoiler ("_open") _ @text ("_close"))@icon',
        highlight = "@neorg.markup.spoiler",
        icon = function(buffer, node) return ("•"):rep(vim.treesitter.get_node_text(node, buffer):len()-2), 1 end,
    },

    unordered_list1_prefix = { icon = "•", },
    unordered_list2_prefix = { icon = " •", },
    unordered_list3_prefix = { icon = "  •", },
    unordered_list4_prefix = { icon = "   •", },
    unordered_list5_prefix = { icon = "    •", },
    unordered_list6_prefix = {
        icon = function(buffer, node) return (" "):rep(get_prefix_level(buffer, node) - 1) .. "•" end,
    },

    ordered_list1_prefix = {
        icon = function(...) return get_ordered_icon(conceal_icon_table.numeric_dot, ...) end
    },

    ordered_list2_prefix = {
        icon = function(...) return get_ordered_icon(conceal_icon_table.latin_uppercase, ...) end
    },

    ordered_list3_prefix = {
        icon = function(...) return get_ordered_icon(conceal_icon_table.latin_lowercase, ...) end
    },

    ordered_list4_prefix = {
        icon = function(...) return get_ordered_icon(conceal_icon_table.numeric_pareneses, ...) end
    },

    ordered_list5_prefix = {
        icon = function(...) return get_ordered_icon(conceal_icon_table.latin_uppercase, ...) end
    },

    ordered_list6_prefix = {
        icon = function(buffer, node)
            local level = get_prefix_level(buffer, node)
            local icon_tables = {
                conceal_icon_table.latin_lowercase_parentheses,
                conceal_icon_table.latin_uppercase_circled,
                conceal_icon_table.latin_lowercase_circled,
                conceal_icon_table.numeric_circled,
                conceal_icon_table.numeric,
            }
            local the_icon_table = icon_tables[level-6+1] or icon_tables[#icon_tables]
            return get_ordered_icon(the_icon_table, buffer, node)
        end
    },
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

table_extend_in_place(conceal_texts, {
    link_target_heading1 = vim.tbl_extend("error", conceal_texts.heading1_prefix, { conceal = "." }),
    link_target_heading2 = vim.tbl_extend("error", conceal_texts.heading2_prefix, { conceal = "." }),
    link_target_heading3 = vim.tbl_extend("error", conceal_texts.heading3_prefix, { conceal = "." }),
    link_target_heading4 = vim.tbl_extend("error", conceal_texts.heading4_prefix, { conceal = "." }),
    link_target_heading5 = vim.tbl_extend("error", conceal_texts.heading5_prefix, { conceal = "." }),
    link_target_heading6 = vim.tbl_extend("error", conceal_texts.heading6_prefix, { conceal = "." }),
    -- TODO: link, definition, footnote, 
})

local function remove_extmarks(buffer, row_start, row_end)
    assert(row_start <= row_end)
    if row_start == row_end then
        return
    end
    for _, result in ipairs(vim.api.nvim_buf_get_extmarks(buffer, my_namespace, {row_start,0}, {row_end-1,-1}, {})) do
        vim.api.nvim_buf_del_extmark(buffer, my_namespace, result[1])
    end
end

local function conceal_range(buffer, row_start, row_end)
    -- FIXME: markup across lines?

    -- in case there's undo/removal garbage
    -- TODO: optimize
    row_end = row_end + 2
    remove_extmarks(buffer, row_start, row_end)

    -- one single query
    -- iterate
    -- if conceallable
    -- set conceal

    local treesitter_module = module.required["core.integrations.treesitter"]
    local document_root = treesitter_module.get_document_root(buffer)
    assert(document_root)

    for id, node, _metadata in conceal_query:iter_captures(document_root, buffer, row_start, row_end) do
        local r, c, _ = node:start()
        local text = conceal_texts[node:type()]
        local icon, col_offset
        if type(text.icon)=="string" then
            icon = text.icon
        else
            icon, col_offset = text.icon(buffer, node)
        end
        c = c + (col_offset or 0)
        local opt = {
            virt_text={{icon, text.highlight}},
            --virt_text_pos="overlay",
            virt_text_win_col=c,
            hl_group=nil,
            conceal=text.conceal,
            id=nil,
            end_row=nil, --r,
            end_col=nil, --c+icon:len(),
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
        local id = vim.api.nvim_buf_set_extmark(buffer, my_namespace, r, c, opt)
    end
end

operations_of_buf = {}
scheduled = false

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

local function table_remove_interval(tbl, l, r)
    assert(0 <= l)
    assert(l <= r)
    assert(r <= #tbl + 1)

    if l == r then
        return
    end

    table.move(tbl, r, #tbl, l)

    for i = l, r-1 do
        tbl[#tbl] = nil
    end
end

local function do_operations_for_buffer(buffer, operations)
    assert(not vim.tbl_isempty(operations))
    --regenerate_full(buffer)

    -- invariant:
    -- 0 <= itv.l <= itv.r  forall itv
    -- itv.r < itv'.l   forall adjacent itv and itv'
    local changed_intervals = {}

    for _, op in ipairs(operations) do
        local il = table_ifind_first(changed_intervals, function(itv) return op.row_start <= itv.l end)
        local ir = table_ifind_first(changed_intervals, function(itv) return op.row_end_old < itv.l end, l)

        if il>1 and op.row_start <= changed_intervals[il-1].r then
            il = il - 1
        elseif il==ir then
            table.insert(changed_intervals, il, { l = op.row_start, r = op.row_end_old })
            ir = ir + 1
        else
            assert(op.row_start <= changed_intervals[il].l)
            changed_intervals[il].l = op.row_start
        end
        changed_intervals[il].r = math.max(op.row_end_old, changed_intervals[ir-1].r)
        table_remove_interval(changed_intervals, il+1, ir)
        local end_diff = op.row_end_new - op.row_end_old
        if end_diff ~= 0 then
            for i = il, #changed_intervals do
                changed_intervals[i].r = changed_intervals[i].r + end_diff
                assert(changed_intervals[i].l <= changed_intervals[i].r)
                assert(i == il or (changed_intervals[i].l < changed_intervals[i].r))
            end
        end
    end

    assert(not vim.tbl_isempty(changed_intervals))
    local overall_l = changed_intervals[1].l
    local overall_r = changed_intervals[#changed_intervals].r
    local n_buf_line = vim.api.nvim_buf_line_count(buffer)
    assert(0 <= overall_l)
    assert(overall_l <= overall_r)
    assert(overall_r <= n_buf_line)
    conceal_range(buffer, overall_l, overall_r)
end

local function do_operations_for_all_buffers()
    print('$$$ do_operations_for_all_buffers')
    -- local old_lazyredraw = vim.go.lazyredraw
    -- vim.go.lazyredraw = true
    for buffer, operations in pairs(operations_of_buf) do
        do_operations_for_buffer(buffer, operations)
        --table_iclear(operations)
    end
    operations_of_buf = {}
    -- vim.go.lazyredraw = old_lazyredraw
    scheduled = false
end

local function add_operation(buffer, op)
    local operations = operations_of_buf[buffer]
    if operations == nil then
        operations = {}
        operations_of_buf[buffer] = operations
    end

    table.insert(operations, op)
    if not scheduled then
        scheduled = true
        vim.schedule(do_operations_for_all_buffers)
    end
end

local function handle_bufread(event)
    assert(vim.api.nvim_win_is_valid(event.window))

    local function on_bytes_callback(_tag, buffer, _changedtick, row_start, col_start, byte_offset, old_row_end, old_col_end, old_byte_changed, new_row_end, new_col_end, new_byte_changed)
        assert(_tag == "bytes")
        print(("@@@@ on_byte, start=(%s,%s), byte_offset=%s, old_end=(%s,%s):%s, new_end=(%s,%s):%s"):format(
        row_start, col_start, byte_offset, old_row_end, old_col_end, old_byte_changed, new_row_end, new_col_end, new_byte_changed))
    end

    local function on_line_callback(_tag, buffer, _changedtick, row_start, row_end, row_updated, n_byte_prev)
        assert(_tag == "lines")
        print(("@@@@' on_line, row_start=%s, row_end=%s, row_updated=%s, n_byte_prev=%s"):format(row_start, row_end, row_updated, n_byte_prev))
        add_operation(buffer, {row_start = row_start, row_end_old = row_end, row_end_new = row_updated})
    end

    local attach_succeeded = vim.api.nvim_buf_attach(event.buffer, true, { on_lines = on_line_callback })
    assert(attach_succeeded)

    add_operation(event.buffer, {row_start = 0, row_end_old = 0, row_end_new = vim.api.nvim_buf_line_count(event.buffer)})
end

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufread" then
        if event.content.norg then
            handle_bufread(event)
        end
    elseif event.type == "core.autocommands.events.insertenter" then
        handle_insertenter()
    elseif event.type == "core.autocommands.events.insertleave" then
        handle_insertleave()
    elseif event.type == "core.autocommands.events.vimleavepre" then
        handle_vimleavepre()
    else
        assert(false, ("unexpected event type: %s"):format(event.type))
    end
end

-- TODO;
-- CursorHold
-- inccommand
-- lazyredraw, ttyfast
-- no conceal on cursor line at insert mode

module.events.defined = {
    -- update_region = neorg.events.define(module, "update_region"),
}

module.events.subscribed = {
    ["core.autocommands"] = {
        bufread = true,
        insertenter = true,
        insertleave = true,
        vimleavepre = true,
    },

    ["core.neorgcmd"] = {
        ["core.concealer.toggle"] = true,
    },

    ["core.concealer"] = {
        -- update_region = true,
    },
}

return module
