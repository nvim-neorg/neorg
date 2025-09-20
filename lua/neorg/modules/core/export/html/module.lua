--[[
    file: HTML-Export
    title: Neorg's HTML Exporter
    summary: Interface for `core.export` to allow exporting to HTML.
    ---
This module exists as an interface for `core.export` to export `.norg` files to HTML.
As a user the only reason you would ever have to touch this module is to configure *how* you'd
like your markdown to be exported (i.e. do you want to support certain extensions during the export).
To learn more about configuration, consult the [relevant section](#configuration).
--]]

-- TODO: One day this module will need to be restructured or maybe even rewritten.
-- It's not atrocious, but there are a lot of moving parts that make it difficult to understand
-- from another person's perspective. Some cleanup and rethinking of certain implementation
-- details will be necessary.

local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.export.html")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.esupports.hop",
        },
    }
end

--- Enumeration of different stackk types
---@enum StackKey
local StackKey = {
    LIST = "list",
    BLOCK_QUOTE = "blockquote",
    SPAN = "span",
}

--- Enumeration of differnete link target types.
--- @enum HeadingType
local HeadingType = {
    HEADING1 = "h1",
    HEADING2 = "h2",
    HEADING3 = "h3",
    HEADING4 = "h4",
    HEADING5 = "h5",
    HEADING6 = "h6",
}

--- @class Location
--- @field file string
--- @field text string
--- @field type HeadingType
---
--- @class FragmentArgs
--- @field type string
--- @field text string

--> Generic Utility Functions

--- Escapes unsafe characters in the string
---@param text string string being escaped
---@return string
local function html_escape(text)
    local escaped_text =
        text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
    return escaped_text
end

--- Applies HTML escaping to a word node
---@param word string
---@return  table
local function escape_word(word)
    return {
        output = html_escape(word),
    }
end

--- Adds opening tag and pushes closing tag onto stack to be popped in a recollector.
---@param tag string
---@param level number
---@param stack_key StackKey
---@return fun(_: any, _: any, state: table): table
local function nest_tag(tag, level, stack_key)
    return function(text, _, state)
        if not state.nested_tag_stacks[stack_key] then
            state.nested_tag_stacks[stack_key] = {}
        end

        local attributes = ""
        if stack_key == StackKey.SPAN then
            attributes = ' id="generic-' .. text:lower():gsub("<", ""):gsub(">", ""):gsub(" ", "") .. '" '
        end

        local output = ""
        local opening_tag = "\n<" .. tag .. attributes .. ">\n"
        local closing_tag = "\n</" .. tag .. ">\n"

        while level > #state.nested_tag_stacks[stack_key] do
            output = output .. opening_tag
            table.insert(state.nested_tag_stacks[stack_key], closing_tag)
        end

        while level < #state.nested_tag_stacks[stack_key] do
            output = output .. table.remove(state.nested_tag_stacks[stack_key])
        end

        return {
            output = output,
            keep_descending = true,
        }
    end
end

--- Recollects tags by popping them off the stack and appending them to the
--- output
---@param stack_key StackKey
---@return fun(output: table, state: table): table
local function nested_tag_recollector(stack_key)
    return function(output, state)
        local suffix = ""

        local closing_tag = table.remove(state.nested_tag_stacks[stack_key])
        while closing_tag do
            suffix = suffix .. closing_tag
            closing_tag = table.remove(state.nested_tag_stacks[stack_key])
        end

        table.insert(output, suffix)

        return output
    end
end

--- Return true when a given stack key is empty
---@param state table
---@param stack_key StackKey
---@return boolean
local function is_stack_empty(state, stack_key)
    return not state.nested_tag_stacks[stack_key] or #state.nested_tag_stacks[stack_key] == 0
end

---@param heading_type HeadingType
---@param target_type LinkType
---@return fun(): table
local function heading(heading_type, target_type)
    return function()
        return {
            output = "<div>\n",
            keep_descending = true,
            state = {
                heading = heading_type,
                target_type = target_type,
            },
        }
    end
end

---Appends the closing p tag when required
---@param output table
---@param state table
---@return table
local function add_closing_p_tag(output, state)
    if not state.link and is_stack_empty(state, StackKey.LIST) and is_stack_empty(state, StackKey.SPAN) then
        local new_output = { "\n<p>\n" }
        for _, value in ipairs(output) do
            table.insert(new_output, value)
        end
        table.insert(new_output, "\n</p>\n")
        output = new_output
    end

    return output
end

---Appends a given tag to the output
---@param tag string
---@param cleanup? fun(state)
---@return fun(output: table, state: table): table
local function add_closing_tag(tag, cleanup)
    return function(output, state)
        table.insert(output, tag)
        if cleanup then
            cleanup(state)
        end
        return output
    end
end

---Builds a link and adds it to the output givne recollected data in the state table.
---@return fun(_: any, state: table): table
local function wrap_anchor()
    return function(output, state)
        local link_builder = module.config.public.link_builders.link_builder

        local href
        if state.link then
            href = link_builder(state.link)
        else
            href = ""
        end

        local content
        if #output > 0 and output[1] ~= "" then
            content = output[1]
        else
            content = state.link.link_text
        end

        output = {
            '<a href="' .. href .. '">',
            content,
            "</a>",
        }

        state.link = nil

        return output
    end
end

local function set_link(_, node)
    local hop = modules.get_module("core.esupports.hop")
    local link = hop.parse_link(node, 0)

    return {
        keep_descending = true,
        state = {
            link = link,
        },
    }
end

---Just keeps swimming
---@param state_or_fn? table|fun(): table
---@return fun(): table
local function keep_descending(state_or_fn)
    return function()
        local state
        if type(state_or_fn) == "function" then
            state = state_or_fn()
        else
            state = state_or_fn
        end

        return {
            output = "",
            keep_descending = true,
            state = state,
        }
    end
end

---@param output table
---@return table
local function recollect_footnote(output, state)
    local title = table.remove(output, 1) .. table.remove(output, 1)
    local content = table.concat(output)
    local footnote_number = #state.footnotes + 1

    table.insert(state.footnotes, { title = title, content = content, number = footnote_number })

    return {
        '<a href="#footnote-' .. footnote_number .. '">[' .. footnote_number .. "]</a>",
    }
end

---@return fun(text: string, node: TSNode): table
local function ranged_verbatim_tag_content()
    return function(text, node)
        local _, start_column = node:range()
        local indent = ""
        local i = 0
        while i < start_column do
            indent = indent .. " "
            i = i + 1
        end

        return {
            output = "",
            state = {
                tag_content = indent .. text,
                tag_indent_level = start_column,
            },
        }
    end
end

local function init_state()
    return {
        todo = nil,
        tag_params = {},
        tag_close = nil,
        heading = nil,
        ranged_tag_indentation_level = 0,
        is_url = false,
        nested_tag_stacks = {},
        anchors = {},
        link = nil,
        footnotes = {},
    }
end

---@param text string
---@param state  table
---@return table
local function paragraph_segment(text, _, state)
    local output = "\n"
    local fragment_builder = module.config.public.link_builders.fragment_builder

    if state.heading then
        output = "<" .. state.heading .. ' id="' .. fragment_builder({ type = state.target_type, text = text }) .. '">'
        -- Add span to support generic link targets
        output = output .. '<span id="' .. fragment_builder({ type = "generic", text = text }) .. '"></span>'
    end

    local todo = ""
    if state.todo then
        todo = '<span class="todo-status-' .. state.todo .. '"></span>'
        state.todo = nil
    end

    return {
        output = output .. todo,
        keep_descending = true,
    }
end

---@param node TSNode
---@return string
local function get_opening_tag(_, node)
    local parent_type = node:parent():type()
    local tag = module.private.open_close_tags[parent_type]
    if type(tag) == "table" then
        return "<" .. tag.tag .. ' class="' .. tag.class .. '">'
    elseif tag then
        return "<" .. tag .. ">"
    else
        return ""
    end
end

---@param node TSNode
---@return string
local function get_closing_tag(_, node)
    local parent_type = node:parent():type()
    local tag = module.private.open_close_tags[parent_type]

    if type(tag) == "table" then
        return "</" .. tag.tag .. ">"
    elseif tag then
        return "</" .. tag .. ">"
    else
        return ""
    end
end

---@param text string
---@return table
local function add_tag_name(text)
    return {
        output = "",
        state = {
            tag_name = text,
        },
    }
end

---@param text string
---@param state table
---@return table
local function add_tag_param(text, _, state)
    local tag_params = table.insert(state.tag_params, text)

    return {
        output = "",
        state = {
            tag_params = tag_params,
        },
    }
end

---@param output table
---@param state table
---@return table
local function add_closing_segement_tags(output, state)
    if state.heading then
        table.insert(output, "</" .. state.heading .. ">")
        state.heading = nil
        state.target_type = nil
    end

    return output
end

---@param output table
---@param state table
---@return table
local function apply_ranged_tag_handlers(output, state)
    local name = state.tag_name
    local content = state.tag_content
    local params = state.tag_params

    local ranged_tag_handler = module.config.public.ranged_tag_handler[name]
        or module.private.ranged_tag_handler[name]
        or module.private.ranged_tag_handler["comment"]

    table.insert(output, ranged_tag_handler(params, content, state.tag_indent_level))

    state.tag_name = ""
    state.tag_params = {}
    state.tag_content = ""
    state.tag_indent_level = 0

    return output
end

local function build_footnote(footnote)
    return table.concat({
        '\n<div class="footnote" id="footnote-' .. footnote.number .. '">',
        '\n<div class="footnote-number">\n',
        footnote.number,
        "\n</div>",
        '\n<div class="footnote-title">\n',
        footnote.title,
        "\n</div>",
        '\n<div class="footnore-content">\n',
        footnote.content,
        "\n</div>",
        "\n</div>",
        "\n",
    })
end

local function get_anchor(_, node, _)
    local hop = modules.get_module("core.esupports.hop")

    local target = hop.locate_anchor_declaration_target(node)
    local link = nil
    local link_desription = nil
    local anchor_definition = nil
    if target then
        link_desription = target.node:parent()
    end
    if link_desription then
        anchor_definition = link_desription:parent()
    end
    if anchor_definition then
        link = hop.parse_link(anchor_definition, 0)
    end

    return {
        keep_descending = true,
        state = {
            link = link,
        },
    }
end

module.load = function() end

module.config.public = {
    --- If you'd like to modify the way specific range tabs are handled. For
    --- example if you wanted to translate document.meta into use-case specific
    --- HTML, you could so here (see: module.private[ranged_tag_handler""] for
    --- examples).
    ranged_tag_handler = {},
    -- Used by the exporter to know what extension to use
    -- when creating HTML files.
    -- The default is recommended, although you can change it.
    extension = "html",
    link_builders = {
        --- Function handler for building just the fragment. The fragment is the part
        --- of the URL that comes after the "#" and it's used for linking to specific
        --- IDs within a file.
        ---@param args FragmentArgs
        ---@return string
        fragment_builder = function(args)
            if args.type == "external_file" or args.type == "url" then
                -- External links and target URLs don't have target support by default.
                return ""
            end
            local text = args.text or ""

            return args.type .. "-" .. text:lower():gsub(" ", "")
        end,
        -- Function handler for building just the path URL path.
        ---@param link Link
        ---@return string
        path_builder = function(link)
            local file = link.link_file_text or ""
            if file:match("%$/") then
                local workspace_path = "/"
                local dirman = modules.get_module("core.dirman")
                local current_workspace = dirman.get_current_workspace()
                if current_workspace then
                    workspace_path = "/" .. current_workspace[1] .. "/"
                end
                return (file:gsub("%$/", workspace_path):gsub(".norg", ".html"))
            elseif #file > 0 then
                return (file:gsub("%$", "/"):gsub(".norg", ".html"))
            else
                return ""
            end
        end,
        --- Function handler for building the entire link. If you change this handler
        --- you'll need to change
        ---@param link Link
        ---@return string
        link_builder = function(link)
            if link.link_type == "external_file" then
                local file = link.link_location_text or ""
                return "file://" .. file:gsub(" ", "")
            end

            if link.link_type == "url" then
                return link.link_location_text
            end

            local fragment_builder = module.config.public.link_builders.fragment_builder
            local path_builder = module.config.public.link_builders.path_builder

            return path_builder(link)
                .. "#"
                .. fragment_builder({ type = link.link_type, text = link.link_location_text })
        end,
    },
}

module.private = {
    ranged_tag_handler = {
        ["code"] = function(params, content, indent_level)
            local language = params[1] or ""

            local indent_regex = "^" .. string.rep("%s", indent_level)
            local lines_of_code = {}

            for line in string.gmatch(content, "[^\n]+") do
                local normalized_line = line:gsub(indent_regex, "")
                table.insert(lines_of_code, normalized_line)
            end

            local code_block = html_escape(table.concat(lines_of_code, "\n"))

            return '\n<pre>\n<code class="' .. language .. '">\n' .. code_block .. "\n</code>\n</pre>\n"
        end,

        ["comment"] = function(_, content)
            return "\n<!--\n" .. content .. "\n-->\n"
        end,
    },
    open_close_tags = {
        ["bold"] = "b",
        ["italic"] = "i",
        ["underline"] = "u",
        ["strikethrough"] = "s",
        ["spoiler"] = { tag = "span", class = "spoiler" },
        ["verbatim"] = { tag = "code", class = "verbatim" },
        ["superscript"] = "sup",
        ["subscript"] = "sub",
        ["inline_math"] = { tag = "code", class = "inline-math" },
    },
}

--- @class core.export.html
module.public = {
    export = {
        init_state = init_state,
        functions = {
            ["_word"] = escape_word,
            ["_space"] = escape_word,
            ["_open"] = get_opening_tag,
            ["_close"] = get_closing_tag,
            ["_begin"] = "",
            ["_end"] = "",
            ["escape_sequence"] = keep_descending(),
            ["any_char"] = true,

            ["paragraph_segment"] = paragraph_segment,
            ["paragraph"] = keep_descending(),

            ["heading1"] = heading(HeadingType.HEADING1, "heading1"),
            ["heading2"] = heading(HeadingType.HEADING2, "heading2"),
            ["heading3"] = heading(HeadingType.HEADING3, "heading3"),
            ["heading4"] = heading(HeadingType.HEADING4, "heading4"),
            ["heading5"] = heading(HeadingType.HEADING5, "heading5"),
            ["heading6"] = heading(HeadingType.HEADING6, "heading6"),

            ["inline_link_target"] = nest_tag("span", 1, StackKey.SPAN),

            ["unordered_list1"] = nest_tag("ul", 1, StackKey.LIST),
            ["unordered_list2"] = nest_tag("ul", 2, StackKey.LIST),
            ["unordered_list3"] = nest_tag("ul", 3, StackKey.LIST),
            ["unordered_list4"] = nest_tag("ul", 4, StackKey.LIST),
            ["unordered_list5"] = nest_tag("ul", 5, StackKey.LIST),
            ["unordered_list6"] = nest_tag("ul", 6, StackKey.LIST),
            ["unordered_list1_prefix"] = "\n<li>\n",
            ["unordered_list2_prefix"] = "\n<li>\n",
            ["unordered_list3_prefix"] = "\n<li>\n",
            ["unordered_list4_prefix"] = "\n<li>\n",
            ["unordered_list5_prefix"] = "\n<li>\n",
            ["unordered_list6_prefix"] = "\n<li>\n",

            ["ordered_list1"] = nest_tag("ol", 1, StackKey.LIST),
            ["ordered_list2"] = nest_tag("ol", 2, StackKey.LIST),
            ["ordered_list3"] = nest_tag("ol", 3, StackKey.LIST),
            ["ordered_list4"] = nest_tag("ol", 4, StackKey.LIST),
            ["ordered_list5"] = nest_tag("ol", 5, StackKey.LIST),
            ["ordered_list6"] = nest_tag("ol", 6, StackKey.LIST),
            ["ordered_list1_prefix"] = "\n<li>\n",
            ["ordered_list2_prefix"] = "\n<li>\n",
            ["ordered_list3_prefix"] = "\n<li>\n",
            ["ordered_list4_prefix"] = "\n<li>\n",
            ["ordered_list5_prefix"] = "\n<li>\n",
            ["ordered_list6_prefix"] = "\n<li>\n",

            ["quote1"] = nest_tag("blockquote", 1, StackKey.BLOCK_QUOTE),
            ["quote2"] = nest_tag("blockquote", 2, StackKey.BLOCK_QUOTE),
            ["quote3"] = nest_tag("blockquote", 3, StackKey.BLOCK_QUOTE),
            ["quote4"] = nest_tag("blockquote", 4, StackKey.BLOCK_QUOTE),
            ["quote5"] = nest_tag("blockquote", 5, StackKey.BLOCK_QUOTE),
            ["quote6"] = nest_tag("blockquote", 6, StackKey.BLOCK_QUOTE),

            ["tag_parameters"] = keep_descending(function()
                return { tag_params = {} }
            end),
            ["tag_name"] = add_tag_name,
            ["tag_param"] = add_tag_param,
            ["ranged_verbatim_tag_content"] = ranged_verbatim_tag_content(),

            ["todo_item_done"] = keep_descending({ todo = "done" }),
            ["todo_item_undone"] = keep_descending({ todo = "undone" }),
            ["todo_item_pending"] = keep_descending({ todo = "pending" }),
            ["todo_item_urgent"] = keep_descending({ todo = "urgent" }),
            ["todo_item_cancelled"] = keep_descending({ todo = "cancelled" }),
            ["todo_item_recurring"] = keep_descending({ todo = "recurring" }),
            ["todo_item_on_hold"] = keep_descending({ todo = "on_hold" }),
            ["todo_item_uncertain"] = keep_descending({ todo = "uncertain" }),

            ["single_footnote"] = keep_descending(),
            ["multi_footnote"] = keep_descending(),

            ["link"] = set_link,
            ["anchor_definition"] = set_link,
            ["anchor_declaration"] = get_anchor,

            ["strong_carryover"] = "",
            ["weak_carryover"] = "",

            -- [UNSUPPORTED] Infirm Tags are not currently supported, TS parsing
            -- is returning unexpected ranges for .image tag, specically "http:"
            -- gets included as a param and then the rest of hte URL is moved to
            -- the following paragraph as content.
            ["infirm_tag"] = "",
        },

        recollectors = {
            ["paragraph"] = add_closing_p_tag,
            ["paragraph_segment"] = add_closing_segement_tags,

            ["link"] = wrap_anchor(),
            ["anchor_definition"] = wrap_anchor(),
            ["anchor_declaration"] = wrap_anchor(),

            ["generic_list"] = nested_tag_recollector(StackKey.LIST),
            ["quote"] = nested_tag_recollector(StackKey.BLOCK_QUOTE),
            ["inline_link_target"] = nested_tag_recollector(StackKey.SPAN),

            ["heading1"] = add_closing_tag("\n</div>\n"),
            ["heading2"] = add_closing_tag("\n</div>\n"),
            ["heading3"] = add_closing_tag("\n</div>\n"),
            ["heading4"] = add_closing_tag("\n</div>\n"),
            ["heading5"] = add_closing_tag("\n</div>\n"),
            ["heading6"] = add_closing_tag("\n</div>\n"),

            ["unordered_list1"] = add_closing_tag("\n</li>\n"),
            ["unordered_list2"] = add_closing_tag("\n</li>\n"),
            ["unordered_list3"] = add_closing_tag("\n</li>\n"),
            ["unordered_list4"] = add_closing_tag("\n</li>\n"),
            ["unordered_list5"] = add_closing_tag("\n</li>\n"),
            ["unordered_list6"] = add_closing_tag("\n</li>\n"),
            ["ordered_list1"] = add_closing_tag("\n</li>\n"),
            ["ordered_list2"] = add_closing_tag("\n</li>\n"),
            ["ordered_list3"] = add_closing_tag("\n</li>\n"),
            ["ordered_list4"] = add_closing_tag("\n</li>\n"),
            ["ordered_list5"] = add_closing_tag("\n</li>\n"),
            ["ordered_list6"] = add_closing_tag("\n</li>\n"),

            ["ranged_verbatim_tag_end"] = apply_ranged_tag_handlers,

            ["single_footnote"] = recollect_footnote,
            ["multi_footnote"] = recollect_footnote,
        },

        cleanup = function(output, state)
            if #state.footnotes > 0 then
                output = output .. "\n<hr />\n"
            end

            for _, footnote in ipairs(state.footnotes) do
                output = output .. "\n" .. build_footnote(footnote)
            end
            return output
        end,
    },
}

return module
