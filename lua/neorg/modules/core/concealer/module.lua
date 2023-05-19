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

local function myprint(...)
    --[[
    print(...)
    --]]
end

local function in_range(k, l, r_ex)
    return l<=k and k<r_ex
end

local function node_followed_by(node, next_node_type)
    local n = node:parent()
    n = n and n:next_named_sibling()
    return n and (n:type() == next_node_type)
end

local function is_followed_by_link_description(node)
    return node_followed_by(node, "link_description")
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

local function table_extend_in_place(tbl, tbl_ext)
    for k,v in pairs(tbl_ext) do
        tbl[k] = v
    end
end

local function node_length(node)
    local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()
    assert(row_start_0b == row_end_0bin)
    return col_end_0bex - col_start_0b
end

local function is_prefix_node(node)
    return node:type():match("_prefix$") ~= nil or node:type():match("^link_target_heading") ~= nil
end

local function get_node_position_and_text_length(bufid, node)
    -- assert(is_node(node), node:type())
    local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()

    -- FIXME parser: multi_definition_suffix should not span across lines
    -- assert(row_start_0b == row_end_0bin, row_start_0b .. "," .. row_end_0bin)
    local past_end_offset_1b = vim.treesitter.get_node_text(node, bufid):find("%s") or (col_end_0bex - col_start_0b + 1)
    return row_start_0b, col_start_0b, (past_end_offset_1b - 1)
end

local function get_header_prefix_node(header_node)
    local first_child = header_node:child(0)
    assert(first_child:type() == header_node:type() .. "_prefix")
    return first_child
end

local function get_line_length(bufid, row_0b)
    return vim.api.nvim_strwidth(vim.api.nvim_buf_get_lines(bufid, row_0b, row_0b+1, true)[1])
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
    local func_name = debug.getinfo(2, "n")["name"]
    local n_arg = select("#", ...)
    local args = {...}
    for i = 1,n_arg do
        args[i] = tostring(args[i])
    end
    myprint('[logging]', tag, func_name.."("..table.concat(args,", ")..")")
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
    ns_icon = vim.api.nvim_create_namespace("neorg-conceals"),
    ns_prettify_flag = vim.api.nvim_create_namespace("neorg-conceals.prettify-flag"),
    rerendering_scheduled = {},
    enabled = true,
}

local function set_mark(bufid, row_0b, col_0b, text, highlight, ext_opts)
    local ns_icon = module.private.ns_icon
    local opt = {
        virt_text=text and {{text, highlight}},
        virt_text_pos="overlay",
        virt_text_win_col=nil, --col_0b,
        hl_group=nil,
        conceal=nil,
        id=nil,
        end_row=row_0b,
        end_col=col_0b,
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
        table_extend_in_place(opt, ext_opts)
    end
    local _id = vim.api.nvim_buf_set_extmark(bufid, ns_icon, row_0b, col_0b, opt)
end

local function set_mark_many(bufid, row_0b, col_0b, virt_texts)
    for i in 1, #virt_texts do
        set_mark(bufid, row_0b, col_0b, virt_texts[i][1], virt_texts[i][2])
    end
end

local function table_get_default_last(tbl, index)
    return tbl[index] or tbl[#tbl]
end

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

local function get_number_table(initial_number)
    -- TODO: error handling
    for _, number_table in pairs(prettify_icon_table) do
        if number_table[1] == initial_number then
            return number_table
        end
    end
end

local function get_ordered_index(bufid, prefix_node)
    -- TODO: calculate levels in one pass, since treesitter API implementation seems to have ridiculously high complexity
    local _, _, level = get_node_position_and_text_length(bufid, prefix_node)
    local header_node = prefix_node:parent()
    assert(header_node:type() .. "_prefix" == prefix_node:type())
    local sibling = header_node:prev_named_sibling()
    local count = 1

    while sibling and (sibling:type() == header_node:type()) do
        local _, _, sibling_level = get_node_position_and_text_length(bufid, get_header_prefix_node(sibling))
        if sibling_level<level then
            break
        elseif sibling_level==level then
            count = count + 1
        end
        sibling = sibling:prev_named_sibling()
    end

    return count, (sibling or header_node:parent())
end

---@class core.concealer
module.public = {
    foldtext = function()
        local foldstart = vim.v.foldstart
        local line = vim.api.nvim_buf_get_lines(0, foldstart - 1, foldstart, true)[1]

        return neorg.lib.match(line, function(lhs, rhs)
            return vim.startswith(lhs, rhs)
        end)({
            ["@document.meta"] = "Document Metadata",
            _ = function()
                local line_length = vim.api.nvim_strwidth(line)

                local icon_extmarks = vim.api.nvim_buf_get_extmarks(
                    0,
                    module.private.icon_namespace,
                    { foldstart - 1, 0 },
                    { foldstart - 1, line_length },
                    {
                        details = true,
                    }
                )

                for _, extmark in ipairs(icon_extmarks) do
                    local extmark_details = extmark[4]
                    local extmark_column = extmark[3] + (line_length - vim.api.nvim_strwidth(line))

                    for _, virt_text in ipairs(extmark_details.virt_text or {}) do
                        line = line:sub(1, extmark_column)
                            .. virt_text[1]
                            .. line:sub(extmark_column + vim.api.nvim_strwidth(virt_text[1]) + 1)
                        line_length = vim.api.nvim_strwidth(line) - line_length + vim.api.nvim_strwidth(virt_text[1])
                    end
                end

                return line
            end,
        })
    end,

    icon_renderers =  {
        on_left = function(config, bufid, node)
            print(node, '#.')
            local row_0b, col_0b, len = get_node_position_and_text_length(bufid, node)
            local text = (" "):rep(len-1) .. config.icon
            set_mark(bufid, row_0b, col_0b, text, config.highlight)
        end,

        multilevel_on_right = function(config, bufid, node)
            local row_0b, col_0b, len = get_node_position_and_text_length(bufid, node)
            local text = (" "):rep(len-1) .. table_get_default_last(config.icons, len)
            local highlight = config.highlights and table_get_default_last(config.highlights, len)
            set_mark(bufid, row_0b, col_0b, text, highlight)
        end,

        multilevel_ordered_on_right = function(config, bufid, node)
            local row_0b, col_0b, len = get_node_position_and_text_length(bufid, node)
            local initial_number = table_get_default_last(config.icons, len)
            local number_table = get_number_table(initial_number)
            local index = get_ordered_index(bufid, node)
            local text = (" "):rep(len-1) .. (number_table[index] or "~")
            local highlight = config.highlights and table_get_default_last(config.highlights, len)
            set_mark(bufid, row_0b, col_0b, text, highlight)
        end,

        multilevel_copied = function(config, bufid, node)
            local row_0b, col_0b, len = get_node_position_and_text_length(bufid, node)
            local virt_texts = {}
            local last_icon, last_highlight
            for i = 1, len do
                last_icon = config.icons[i] or last_icon
                last_highlight = config.highlights[i] or last_highlight
                set_mark(bufid, row_0b, col_0b+(i-1), last_icon, last_highlight)
            end
        end,

        fill_text = function(config, bufid, node)
            local row_0b, col_0b, len = get_node_position_and_text_length(bufid, node)
            local text = config.icon:rep(len)
            set_mark(bufid, row_0b, col_0b, text, config.highlight)
        end,

        fill_multiline_chop2 = function(config, bufid, node)
            local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()
            for i = row_start_0b, row_end_0bin do
                local l = i==row_start_0b and col_start_0b+1 or 0
                local r_ex = i==row_end_0bin and col_end_0bex-1 or get_line_length(bufid, i)
                set_mark(bufid, i, l, config.icon:rep(r_ex-l), config.highlight)
            end
        end,

        fill_width = function(config, bufid, node)
            -- TODO: from node's column?
            local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()
            local line_len = vim.api.nvim_win_get_width(0)
            set_mark(bufid, row_start_0b, 0, config.icon:rep(line_len), config.highlight)
        end,

        render_code_block = function(config, bufid, node)
            --
            -- TODO: check "code" or "embed"
            -- TODO: content_only
            -- TODO: padding
            -- TODO: conceal
            -- TODO: width
            local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()
            assert(row_start_0b < row_end_0bin)

            if config.conceal then
                for _, row_0b in ipairs({row_start_0b, row_end_0bin}) do
                    vim.api.nvim_buf_set_extmark(bufid, module.private.ns_icon, row_0b, 0, { end_col = get_line_length(bufid, row_0b), conceal = "" })
                end
            end

            if has_conceal or config.content_only then
                row_start_0b = row_start_0b + 1
                row_end_0bin = row_end_0bin - 1
            end

            local line_lengths = {}
            local max_len = 0
            for row_0b = row_start_0b, row_end_0bin do
                local len = get_line_length(bufid, row_0b)
                if len > max_len then
                    max_len = len
                end
                table.insert(line_lengths, len)
            end

            local to_eol = (config.width ~= "content")

            for row_0b = row_start_0b, row_end_0bin do
                local len = line_lengths[row_0b - row_start_0b + 1]
                local mark_col_start_0b = math.max(0, col_start_0b - config.padding.left)
                local mark_col_end_0bex = not to_eol and (max_len + config.padding.right) or nil
                if mark_col_start_0b < len then
                    ---[[
                    vim.api.nvim_buf_set_extmark(bufid, module.private.ns_icon, row_0b, mark_col_start_0b, {
                        end_row = row_0b+1,
                        hl_eol = to_eol,
                        hl_group = config.highlight,
                        hl_mode = "blend",
                        virt_text_pos = "overlay",
                        virt_text_win_col = 7,
                    })
                    --]]
                end
                if mark_col_end_0bex and mark_col_end_0bex > len then
                    ---[[
                    vim.api.nvim_buf_set_extmark(bufid, module.private.ns_icon, row_0b, len, {
                        end_row = row_0b+1,
                        hl_mode = "blend",
                        virt_text = { { (" "):rep(mark_col_end_0bex - len), config.highlight } },
                        virt_text_pos = "overlay",
                        virt_text_win_col = len,
                    })
                    --]]
                end
            end
            --[[
            for row_0b = 43, 43 do
                vim.api.nvim_buf_set_extmark(bufid, module.private.ns_icon, row_0b, 7, {
                    end_row = row_0b+1,
                    hl_eol = false,
                    hl_group = "@neorg.tags.ranged_verbatim.code_block",
                    hl_mode = "blend",
                    virt_text_pos = "overlay",
                    virt_text_win_col = 7,
                })
                vim.api.nvim_buf_set_extmark(bufid, module.private.ns_icon, row_0b,  14, {
                    end_row = row_0b+1,
                    hl_eol = false,
                    hl_mode = "blend",
                    virt_text = { { "          ", "@neorg.tags.ranged_verbatim.code_block" } },
                    virt_text_pos = "overlay",
                    virt_text_win_col = 14
                })
            end
            --]]
            --[[
            local row_0b = 43
            local highlight = config.highlight
            vim.api.nvim_buf_set_extmark(bufid, module.private.ns_icon, row_0b,  7, {
                end_row = 43+1,
                hl_eol = true,
                hl_group = highlight,
                hl_mode = "blend",
                virt_text_pos = "overlay",
            })
            vim.api.nvim_buf_set_extmark(bufid, module.private.ns_icon, row_0b,  14, {
                end_row = 43+1,
                --hl_eol = true,
                hl_mode = "blend",
                virt_text = { { "          ", highlight } },
                virt_text_pos = "overlay",
                virt_text_win_col = 14
            })
            --]]
        end,
    },
}

module.config.public = {
    icon_preset = "basic",

    folds = true,

    icons = {
        todo = {
            done = {
                icon = "󰄬",
                nodes = { "todo_item_done" },
                render = module.public.icon_renderers.on_left,
            },
            pending = {
                icon = "󰥔",
                nodes = { "todo_item_pending" },
                render = module.public.icon_renderers.on_left,
            },
            undone = {
                icon = "×",
                nodes = { "todo_item_undone" },
                render = module.public.icon_renderers.on_left,
            },
            uncertain = {
                icon = "",
                nodes = { "todo_item_uncertain" },
                render = module.public.icon_renderers.on_left,
            },
            on_hold = {
                icon = "",
                nodes = { "todo_item_on_hold" },
                render = module.public.icon_renderers.on_left,
            },
            cancelled = {
                icon = "",
                nodes = { "todo_item_cancelled" },
                render = module.public.icon_renderers.on_left,
            },
            recurring = {
                icon = "↺",
                nodes = { "todo_item_recurring" },
                render = module.public.icon_renderers.on_left,
            },
            urgent = {
                icon = "⚠",
                nodes = { "todo_item_urgent" },
                render = module.public.icon_renderers.on_left,
            },
        },

        list = {
            icons = { "•" },
            nodes = {
                "unordered_list1_prefix",
                "unordered_list2_prefix",
                "unordered_list3_prefix",
                "unordered_list4_prefix",
                "unordered_list5_prefix",
                "unordered_list6_prefix",
            },
            render = module.public.icon_renderers.multilevel_on_right,
        },
        ordered = {
            icons = { "⒈", "A", "a", "⑴", "Ⓐ", "ⓐ" },
            nodes = {
                "ordered_list1_prefix",
                "ordered_list2_prefix",
                "ordered_list3_prefix",
                "ordered_list4_prefix",
                "ordered_list5_prefix",
                "ordered_list6_prefix",
            },
            render = module.public.icon_renderers.multilevel_ordered_on_right,
        },
        quote = {
            icons = { "|" },
            nodes = {
                "quote1_prefix",
                "quote2_prefix",
                "quote3_prefix",
                "quote4_prefix",
                "quote5_prefix",
                "quote6_prefix",
            },
            highlights = {
                "@neorg.quotes.1.prefix",
                "@neorg.quotes.2.prefix",
                "@neorg.quotes.3.prefix",
                "@neorg.quotes.4.prefix",
                "@neorg.quotes.5.prefix",
                "@neorg.quotes.6.prefix",
            },
            render = module.public.icon_renderers.multilevel_copied,
        },
        heading = {
            icons = { "◉", "◎", "○", "✺", "▶", "⤷" },
            highlights = {
                "@neorg.headings.1.prefix",
                "@neorg.headings.2.prefix",
                "@neorg.headings.3.prefix",
                "@neorg.headings.4.prefix",
                "@neorg.headings.5.prefix",
                "@neorg.headings.6.prefix",
            },
            nodes = {
                "heading1_prefix",
                "heading2_prefix",
                "heading3_prefix",
                "heading4_prefix",
                "heading5_prefix",
                "heading6_prefix",
                concealed = {
                    "link_target_heading1",
                    "link_target_heading2",
                    "link_target_heading3",
                    "link_target_heading4",
                    "link_target_heading5",
                    "link_target_heading6",
                },
            },
            check_conceal = is_followed_by_link_description,
            render = module.public.icon_renderers.multilevel_on_right,
        },
        definition = {
            single = {
                icon = "≡",
                nodes = { "single_definition_prefix", concealed = { "link_target_definition" }},
                check_conceal = is_followed_by_link_description,
                render = module.public.icon_renderers.on_left,
            },
            multi_prefix = {
                icon = "⋙ ",
                nodes = { "multi_definition_prefix" },
                render = module.public.icon_renderers.on_left,
            },
            multi_suffix = {
                icon = "⋘ ",
                nodes = { "multi_definition_suffix" },
                render = module.public.icon_renderers.on_left,
            },
        },

        footnote = {
            single = {
                icon = "⁎",
                nodes = { "single_footnote_prefix", concealed = { "link_target_footnote" } },
                check_conceal = is_followed_by_link_description,
                render = module.public.icon_renderers.on_left,
            },
            multi_prefix = {
                icon = "⁑ ",
                nodes = { "multi_footnote_prefix" },
                render = module.public.icon_renderers.on_left,
            },
            multi_suffix = {
                icon = "⁑ ",
                nodes = { "multi_footnote_suffix" },
                render = module.public.icon_renderers.on_left,
            },
        },

        delimiter = {
            weak = {
                icon = "⟨",
                highlight = "@neorg.delimiters.weak",
                nodes = { "weak_paragraph_delimiter" },
                render = module.public.icon_renderers.fill_text,
            },
            strong = {
                icon = "⟪",
                highlight = "@neorg.delimiters.strong",
                nodes = { "strong_paragraph_delimiter" },
                render = module.public.icon_renderers.fill_text,
            },
            horizontal_line = {
                icon = "─",
                highlight = "@neorg.delimiters.horizontal_line",
                nodes = { "horizontal_line" },
                render = module.public.icon_renderers.fill_width,
            },
        },

        markup = {
            spoiler = {
                icon = "•",
                highlight = "@neorg.markup.spoiler",
                nodes = { "spoiler" },
                render = module.public.icon_renderers.fill_multiline_chop2,
            },
        },

        code_block = {
            -- If true will only dim the content of the code block (without the
            -- `@code` and `@end` lines), not the entirety of the code block itself.
            content_only = true,

            -- The width to use for code block backgrounds.
            --
            -- When set to `fullwidth` (the default), will create a background
            -- that spans the width of the buffer.
            --
            -- When set to `content`, will only span as far as the longest line
            -- within the code block.
            width = "content",

            -- Additional padding to apply to either the left or the right. Making
            -- these values negative is considered undefined behaviour (it is
            -- likely to work, but it's not officially supported).
            padding = {
                left = 3,
                right = 5,
            },

            -- If `true` will conceal (hide) the `@code` and `@end` portion of the code
            -- block.
            conceal = true,

            nodes = { "ranged_verbatim_tag" },
            highlight = "@neorg.tags.ranged_verbatim.code_block",
            render = module.public.icon_renderers.render_code_block,
        },
    },
}



local function get_prefix_level(buffer, prefix_node)
    return select(3, get_node_position_and_text_length(buffer, prefix_node))
end

local function render_heading_prefix(buffer, node, icons, highlights)
    assert(#icons >= 1)
    local level = get_prefix_level(buffer, node)
    local icon = (" "):rep(level - 1) .. (icons[level] or icons[#icons])
    local highlight = highlights and (highlights[level] or highlights[#highlights])
    return icon, highlight
end

local heading_icons_default = { "◉", "◎", "○", "✺", "▶", "⤷" }
local heading_highlights = {
    "@neorg.headings.1.prefix",
    "@neorg.headings.2.prefix",
    "@neorg.headings.3.prefix",
    "@neorg.headings.4.prefix",
    "@neorg.headings.5.prefix",
    "@neorg.headings.6.prefix",
}
local unordered_list_icons_default = { "•" }

local ordered_list_icon_tables_default = {
    prettify_icon_table.numeric_dot,
    prettify_icon_table.latin_uppercase,
    prettify_icon_table.latin_lowercase,
    prettify_icon_table.numeric_pareneses,
    prettify_icon_table.latin_uppercase,
    prettify_icon_table.latin_lowercase_parentheses,
    prettify_icon_table.latin_uppercase_circled,
    prettify_icon_table.latin_lowercase_circled,
    prettify_icon_table.numeric_circled,
    prettify_icon_table.numeric,
}

-- format:
-- "x"
-- function(buffer, node) ... end
-- { icon = "x", highlight = "@foobar", render = function() ... end }


local function checked_gsub(...)
    local result, n_match = string.gsub(...)
    assert(0 <= n_match)
    assert(n_match <= 1)
    assert(result)
    if n_match==1 then
        return result
    end
end

local config_name_dict = {
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


local function link_target_heading_before_description(node)
    local sibling = node:parent():next_named_sibling()
    return sibling and sibling:type() == "link_description"
    -- BUG found: 190-219
end

local function pos_le(pos1, pos2)
    return pos1.x < pos2.x or (pos1.x == pos2.x and pos1.y <= pos2.y)
end

local function pos_lt(pos1, pos2)
    return pos1.x < pos2.x or (pos1.x == pos2.x and pos1.y < pos2.y)
end

local function remove_extmarks(bufid, pos_start_0b_0b, pos_end_0bin_0bex)
    myprint('%%% remove_extmarks', vim.inspect(pos_start_0b_0b), vim.inspect(pos_end_0bin_0bex))
    assert(pos_start_0b_0b.x <= pos_end_0bin_0bex.x)
    local ns_icon = module.private.ns_icon
    for _, result in ipairs(vim.api.nvim_buf_get_extmarks(bufid, ns_icon, {pos_start_0b_0b.x, pos_start_0b_0b.y}, {pos_end_0bin_0bex.x, pos_end_0bin_0bex.y-1}, {})) do
        local extmark_id = result[1]
        local node_pos_0b_0b = { x = result[2], y = result[3] }
        assert(pos_le(pos_start_0b_0b, node_pos_0b_0b) and pos_lt(node_pos_0b_0b, pos_end_0bin_0bex), ("start=%s, end=%s, node=%s"):format(vim.inspect(pos_start_0b_0b), vim.inspect(pos_end_0bin_0bex), vim.inspect(node_pos_0b_0b)))
        vim.api.nvim_buf_del_extmark(bufid, ns_icon, extmark_id)
    end
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
    -- myprint('@@@@@@@ should_skip_prettify =', result, mode, current_row_0b, node, row_start_0b, row_end_0bex, '.')
    return result
end

local function query_get_nodes(query, document_root, bufid, row_start_0b, row_end_0bex)
    local result = {}
    local concealed_node_ids = {}
    for id, node, _metadata in query:iter_captures(document_root, bufid, row_start_0b, row_end_0bex) do
        if query.captures[id] == "icon-concealed" then
            concealed_node_ids[node:id()] = true
        end
        table.insert(result, node)
    end
    return result, concealed_node_ids
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


local function add_prettify_flag_line(bufid, row)
    local ns_prettify_flag = module.private.ns_prettify_flag
    vim.api.nvim_buf_set_extmark(bufid, ns_prettify_flag, row, 0, {})
end

local function add_prettify_flag_range(bufid, row_start_0b, row_end_0bex)
    for row = row_start_0b, row_end_0bex-1 do
        add_prettify_flag_line(bufid, row)
    end
end

local function remove_prettify_flag_on_line(bufid, row_0b)
    -- TODO: optimize
    local ns_prettify_flag = module.private.ns_prettify_flag
    vim.api.nvim_buf_clear_namespace(bufid, ns_prettify_flag, row_0b, row_0b+1)
end

local function remove_prettify_flag_range(bufid, row_start_0b, row_end_0bex)
    -- TODO: optimize
    local ns_prettify_flag = module.private.ns_prettify_flag
    myprint('remove_prettify_flag_range()', bufid, ns_prettify_flag, row_start_0b, row_end_0bex, '.')
    vim.api.nvim_buf_clear_namespace(bufid, ns_prettify_flag, row_start_0b, row_end_0bex)
end

local function remove_prettify_flag_all(bufid)
    remove_prettify_flag_range(bufid, 0, -1)
end

local function get_visible_line_range(winid)
    local row_start_1b = vim.fn.line('w0', winid)
    local row_end_1b = vim.fn.line('w$', winid)
    return (row_start_1b - 1), row_end_1b
end

local function prettify_range(bufid, row_start_0b, row_end_0bex)
    -- in case there's undo/removal garbage
    -- TODO: optimize
    row_end_0bex = math.min(row_end_0bex + 1, vim.api.nvim_buf_line_count(bufid))

    local treesitter_module = module.required["core.integrations.treesitter"]
    local document_root = treesitter_module.get_document_root(bufid)
    local nodes, concealed_node_ids = query_get_nodes(module.private.prettify_query, document_root, bufid, row_start_0b, row_end_0bex)

    local pos_start_0b_0b = { x = row_start_0b, y = 0 }
    local pos_end_0bin_0bex = { x = row_end_0bex-1, y = get_line_length(bufid, row_end_0bex-1) }

    for i = 1, #nodes do
        check_min(pos_start_0b_0b, nodes[i]:start())
        check_max(pos_end_0bin_0bex, nodes[i]:end_())
    end


    remove_extmarks(bufid, pos_start_0b_0b, pos_end_0bin_0bex)
    remove_prettify_flag_range(bufid, pos_start_0b_0b.x, pos_end_0bin_0bex.x+1)
    add_prettify_flag_range(bufid, pos_start_0b_0b.x, pos_end_0bin_0bex.x+1)

    local current_row_0b = vim.api.nvim_win_get_cursor(0)[1] - 1
    local current_mode = vim.api.nvim_get_mode().mode
    local conceallevel = vim.wo.conceallevel
    local concealcursor = vim.wo.concealcursor
    local ns_icon = module.private.ns_icon

    assert(document_root)

    for _, node in ipairs(nodes) do
        -- FIXME skip prettify
        local node_row_start_0b, node_col_start_0b, _node_row_end_0bin, _node_col_end_0bex = node:range()
        local node_row_end_0bex = _node_row_end_0bin + 1

        if should_skip_prettify(current_mode, current_row_0b, node, node_row_start_0b, node_row_end_0bex) then
            goto continue
        end

        local config = module.private.config_by_node_name[node:type()]
        local has_conceal = (concealed_node_ids[node:id()]
            and (not config.check_conceal or config.check_conceal(node))
            and is_concealing_on_row_range(current_mode, conceallevel, concealcursor, current_row_0b, node_row_start_0b, node_row_end_0bex))
        if has_conceal then
            goto continue
        end

        config:render(bufid, node)
        ::continue::
    end
end

local function render_window_buffer(winid, bufid)
    local ns_prettify_flag = module.private.ns_prettify_flag
    local row_start_0b, row_end_0bex = get_visible_line_range(winid)
    local prettify_flags_0b = vim.api.nvim_buf_get_extmarks(bufid, ns_prettify_flag, {row_start_0b,0}, {row_end_0bex-1,-1}, {})
    myprint('prettify_flags_0b = ', vim.inspect(prettify_flags_0b))
    myprint('row_visible = ', row_start_0b, row_end_0bex)
    local row_nomark_start_0b, row_nomark_end_0bin
    local i_flag = 1
    for i = row_start_0b, row_end_0bex-1 do
        if i_flag <= #prettify_flags_0b and i == prettify_flags_0b[i_flag][2] then
            i_flag = i_flag + 1
        else
            assert(i < (prettify_flags_0b[i_flag] and prettify_flags_0b[i_flag][2] or row_end_0bex))
            row_nomark_start_0b = row_nomark_start_0b or i
            row_nomark_end_0bin = i
        end
    end

    myprint('row_nomark = ', row_nomark_start_0b, row_nomark_end_0bin, '.')
    assert((row_nomark_start_0b==nil) == (row_nomark_end_0bin==nil))
    if row_nomark_start_0b then
        prettify_range(bufid, row_nomark_start_0b, row_nomark_end_0bin+1)
    end
end

local function render_all_scheduled_and_done()
    for winid, bufid in pairs(module.private.rerendering_scheduled) do
        render_window_buffer(winid, bufid)
    end
    module.private.rerendering_scheduled = {}
end

local function schedule_rendering(winid, bufid)
    -- FIXME: schedule multiple windows
    local not_scheduled = vim.tbl_isempty(module.private.rerendering_scheduled)
    module.private.rerendering_scheduled[winid] = bufid
    if not_scheduled then
        vim.schedule(render_all_scheduled_and_done)
    end
end

local function mark_line_changed(winid, bufid, row_0b)
    remove_prettify_flag_on_line(bufid, row_0b)
    schedule_rendering(winid, bufid)
end

local function mark_line_range_changed(winid, bufid, row_start_0b, row_end_0bex)
    remove_prettify_flag_range(bufid, row_start_0b, row_end_0bex)
    schedule_rendering(winid, bufid)
end

local function mark_all_lines_changed(winid, bufid)
    remove_prettify_flag_all(bufid)
    schedule_rendering(winid, bufid)
end

local function clear_all_extmarks(bufid)
    local ns_icon = module.private.ns_icon
    local ns_prettify_flag = module.private.ns_prettify_flag
    vim.api.nvim_buf_clear_namespace(bufid, ns_icon, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufid, ns_prettify_flag, 0, -1)
end

local function handle_init_event(event)
    assert(vim.api.nvim_win_is_valid(event.window))

    local function _on_bytes_callback(_tag, bufid, _changedtick, row_start_0b, col_start_0b, byte_offset, old_row_end_0bex, old_col_end_0bex, old_byte_changed, new_row_end_0bex, new_col_end_0bex, new_byte_changed)
        assert(_tag == "bytes")
        myprint(("@@@@ on_byte, start=(%s,%s), byte_offset=%s, old_end=(%s,%s):%s, new_end=(%s,%s):%s"):format(
        row_start_0b, col_start_0b, byte_offset, old_row_end_0bex, old_col_end_0bex, old_byte_changed, new_row_end_0bex, new_col_end_0bex, new_byte_changed))
    end

    local function on_line_callback(_tag, bufid, _changedtick, row_start_0b, row_end_0bex, row_updated_0bex, n_byte_prev)
        assert(_tag == "lines")
        myprint(("@@@@' on_line, time=%s, row_start_0b=%s, row_end=%s, row_updated=%s, n_byte_prev=%s"):format(vim.loop.now(), row_start_0b, row_end_0bex, row_updated_0bex, n_byte_prev))
        mark_line_range_changed(event.window, bufid, row_start_0b, row_updated_0bex)
    end

    local attach_succeeded = vim.api.nvim_buf_attach(event.buffer, true, { on_lines = on_line_callback })
    assert(attach_succeeded)
    local language_tree = vim.treesitter.get_parser(event.buffer, 'norg')

    local bufid = event.buffer
    -- used for detecting non-local (multiline) changes, like spoiler / code block
    -- TODO: exemption in certain cases, for example when changing only heading followed by pure texts,
    -- in which case all its descendents would be unnecessarily re-concealed.
    local function on_changedtree_callback(ranges)
        -- TODO: abandon if too large
        myprint(("@@@@' on_changedtree, ranges=%s"):format(vim.inspect(ranges)))
        for i = 1, #ranges do
            local range = ranges[i]
            local row_start_0b = range[1]
            local row_end_0bex = range[3]+1
            remove_prettify_flag_range(bufid, row_start_0b, row_end_0bex)
        end
    end

    language_tree:register_cbs({ on_changedtree = on_changedtree_callback })
    mark_all_lines_changed(event.window, event.buffer)

    if module.config.public.folds and vim.api.nvim_win_is_valid(event.window) then
        local opts = {
            scope = "local",
            win = event.window,
        }
        vim.api.nvim_set_option_value("foldmethod", "expr", opts)
        vim.api.nvim_set_option_value("foldexpr", "nvim_treesitter#foldexpr()", opts)
        vim.api.nvim_set_option_value(
        "foldtext",
        "v:lua.neorg.modules.get_module('core.concealer').foldtext()",
        opts
        )
    end
end

local function handle_insert_toggle(event)
    mark_line_changed(event.window, event.buffer, event.cursor_position[1]-1)
end

local function handle_insertenter(event)
    myprint('$$$ insertenter', vim.inspect(event))
    handle_insert_toggle(event)
end

local function handle_insertleave(event)
    myprint('$$$ insertleave', vim.inspect(event))
    handle_insert_toggle(event)
end

local function handle_update_region(event)
    -- myprint('@@ handle_update_region')
end

local function handle_toggle_prettifier(event)
    module.private.enabled = not module.private.enabled
    if module.private.enabled then
        mark_all_lines_changed(event.window, event.buffer)
    else
        clear_all_extmarks(event.buffer)
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
    -- reveal/conceal when conceallevel>0
    -- also triggered when dd / u
    if not is_same_line_movement(event) then
        if cursor_record then
            -- leaving previous line, conceal it if necessary
            mark_line_changed(event.window, event.buffer, cursor_record.row_0b)
        end
        -- entering current line, conceal it if necessary
        local current_row_0b = event.cursor_position[1] - 1
        mark_line_changed(event.window, event.buffer, current_row_0b)
    end
    update_cursor(event)
end

local function handle_cursor_moved_i(event)
    return handle_cursor_moved(event)
end

local event_handlers = {
    ["core.neorgcmd.events.core.concealer.toggle"] = handle_toggle_prettifier,
    ["core.autocommands.events.bufread"] = handle_init_event,
    ["core.autocommands.events.insertenter"] = handle_insertenter,
    ["core.autocommands.events.insertleave"] = handle_insertleave,
    ["core.autocommands.events.cursormoved"] = handle_cursor_moved,
    ["core.autocommands.events.cursormovedi"] = handle_cursor_moved_i,
}

module.on_event = function(event)
    if event.referrer == "core.autocommands" and not event.content.norg then
        -- TODO: move to on_event?
        return
    end

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
            callback = function(_ev)
                local winid = vim.fn.win_getid()
                local bufid = vim.api.nvim_get_current_buf()
                if vim.bo[bufid].ft ~= "norg" then
                    return
                end
                mark_all_lines_changed(winid, bufid)
            end,
        })
    end

    -- compile treesitter query
    local function traverse_config(config, f)
        if config.nodes then
            f(config)
            return
        end
        for _, sub_config in pairs(config) do
            traverse_config(sub_config, f)
        end
    end

    local config_by_node_name = {}
    local queries = {"["}

    local function query_node_names(query)
        local node_names = {}
        for node_name in query:gmatch("%(([%w_]+)%)") do
            table.insert(node_names, node_name)
        end
        return node_names
    end

    traverse_config(module.config.public.icons, function(config)
        for _, node_type in ipairs(config.nodes) do
            table.insert(queries, ("(%s)@icon"):format(node_type))
            config_by_node_name[node_type] = config
        end
        for _, node_type in ipairs(config.nodes.concealed or {}) do
            table.insert(queries, ("(%s)@icon-concealed"):format(node_type))
            config_by_node_name[node_type] = config
        end
    end)

    table.insert(queries, "]")
    local query_combined = table.concat(queries, " ")
    local prettify_query = neorg.utils.ts_parse_query("norg", query_combined)
    module.private.prettify_query = prettify_query
    module.private.config_by_node_name = config_by_node_name
end


-- TODO;
-- [x] lazyredraw, ttyfast
-- [x] no conceal on cursor line at insert mode
-- [---------] no conceal inside examples
-- [x] insert mode movement
-- [x] code, spoiler, non-local changes, languagetree (WONTFIX complicated cases)
-- [x]code config
-- [x] conceal links
-- [x] fix toggle-concealer
-- [ ] visual mode skip prettify ("ivV"):find(mode), ModeChanged
-- [+++++++] use vim.b[bufnr]
-- [x] chuncked concealing on demand for large file
-- --- (prev), current, (next): singleton record, changed when moving large steps
-- [++++++] adaptive performance tuning: instant, CursorHold
-- [++++++] multi-column ordering
-- [x] strip heading/list icon
-- number_spec: "§A.a1."
-- digit_infos: { ["A"] = ..., ["a"] = ..., ["1"] = ..., ["⑴"] = ... }
-- result: render({3,5,2,6,7}) = "§C.e2.6.7"
-- [ ] folding
-- [x] remove "enabled" and nestings from config
-- [x] fix: quote level >6
-- rerender on window size change
-- -- details like queries and highlights are closely coupled with the implementation. revealing it to the users are more noisy than helpful

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
