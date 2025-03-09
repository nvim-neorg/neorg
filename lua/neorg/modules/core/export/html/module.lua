--[[
    file: HTML-Export
    title: Neorg's Markdown Exporter
    summary: Interface for `core.export` to allow exporting to markdown.
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
    },
  }
end


--- Enumeration of different stackk types
---@enum StackKey
local StackKey = {
  LIST = "list",
  BLOCK_QUOTE = "blockquote",
}

--- Enumeration of differnete link target types.
local LinkType = {
  HEADING1 = "heading1",
  HEADING2 = "heading2",
  HEADING3 = "heading3",
  HEADING4 = "heading4",
  HEADING5 = "heading5",
  HEADING6 = "heading6",
  GENERIC = "generic",
  EXTERNAL_FILE = "external_file",
  TARGET_URL = "url",
}

--- @class Location
--- @field file string
--- @field text string
--- @field type LinkType

--> Generic Utility Functions

--- Re
---@param tag string
---@param level number
---@param stack_key StackKey
---@return fun(_: any, _: any, state: table): table
local function nest_tag(tag, level, stack_key)
  return function(_, _, state)
    if not state.nested_tag_stacks[stack_key] then
      state.nested_tag_stacks[stack_key] = {}
    end

    local output = ""
    local opening_tag = "\n<" .. tag .. ">\n"
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
  return state.nested_tag_stacks[stack_key] and #state.nested_tag_stacks[stack_key] > 0
end

--- Creates a link description
---@param location Location
---@return string
local function build_link_description(location)
  local description = ""
  if location.file then
    description = description .. '<span class="link-file">' .. location.file .. '</span>'
  end
  if location.text then
    description = description .. '<span class="link-text">' .. location.text .. '</span>'
  end
  return description
end

---
---@param file string
---@return string
local function file_to_path(file)
  if file:match('%$/') then
    local workspace_path = "/"
    local dirman = modules.get_module("core.dirman")
    if dirman then
      local current_workspace = dirman.get_current_workspace()
      if current_workspace then
        workspace_path = "/" .. current_workspace[1] .. "/"
      end
    end
    return (file:gsub('%$/', workspace_path):gsub(".norg", ""))
  elseif #file > 0 then
    return (file:gsub('%$', "/"):gsub(".norg", ""))
  else
    return ""
  end
end

--- Returns href given a Location table
---@param location Location
---@return string
local function build_href(location)
  if not location or not location.type then
    return ""
  end

  if location.type == LinkType.GENERIC then
    return "#generic-" .. location.text:lower():gsub(" ", "")
  elseif location.type == LinkType.EXTERNAL_FILE then
    local file = location.file or ""
    return "file://" .. file:gsub(" ", "") .. "" .. location.text
  elseif location.type == LinkType.TARGET_URL then
    return location.text
  else
    local path = file_to_path(location.file or "")
    local id = location.text:lower():gsub(" ", "")
    return path .. "#" .. location.type .. "-" .. id
  end
end

--> Recollector Utility Functions

---@param target_type LinkType
---@return fun(): table
local function heading(target_type)
  return function()
    return {
      output = "<div>\n",
      keep_descending = true,
      state = {
        heading_target_type = target_type,
      },
    }
  end
end

---@param type LinkType
---@return fun(_: any, _: any, state: table): table
local function set_link_type(type)
  return function(_, _, state)
    state.link.location.type = type

    return {
      output = "",
      keep_descending = true,
    }
  end
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
---@param type "anchor_definition"|"anchor_declaration"|"link"
---@return fun(_: any, state: table): table
local function get_anchor_element(type)
  return function(_, state)
    local href = build_href(state.link.location)
    local content = state.link.description or build_link_description(state.link.location)

    if type == "anchor_definition" then
      state.anchors[content] = href
    elseif type == "anchor_declaration" then
      href = state.anchors[content] or ""
    end

    local output = {
      '<a href="' .. href .. '">',
      content,
      "</a>",
    }

    state.link = nil

    return output
  end
end

---Just keeps swimming
---@param state? table
---@return fun(): table
local function keep_descending(state)
  return function()
    return {
      output = "",
      keep_descending = true,
      state = state
    }
  end
end

---@param output table
---@return table
local function recollect_footnote(output)
  local title = table.remove(output, 1) .. table.remove(output, 1)
  local content = table.concat(output)

  local output_table = {
    "\n<div class=\"footnote\">",
    "\n<div class=\"footnote-title\">\n",
    title,
    "\n</div>",
    "\n<div class=\"footnore-content\">\n",
    content,
    "\n</div>",
    "\n</div>",
    "\n",
  }

  return output_table
end

---Builds a unique ID based on the text that can be used for linking in the future
---@param text string
---@param level number
---@return string
local function build_heading_id(text, level)
  local target_type = heading .. tostring(level)
  return target_type .. "-" .. text:lower():gsub(" ", "")
end

---@return fun(text: string): table
local function ranged_verbatim_tag_content()
  return function(text)
    return {
      output = "",
      state = {
        tag_content = text,
      },
    }
  end
end

local function init_state()
  return {
    todo = nil,
    is_math = false,
    tag_close = nil,
    ranged_tag_indentation_level = 0,
    is_url = false,
    nested_tag_stacks = {},
    anchors = {},
  }
end

---@param text string
---@param state  table
---@return table
local function paragraph_segment(text, _, state)
  local output = ""

  if state.heading and state.heading > 0 then
    output = '<h id="' .. build_heading_id(text, state.heading) .. '">' .. state.heading .. ">"
  elseif is_stack_empty(state, StackKey.LIST) then
    output = "<li>"
  elseif state.is_math then
    output = '<pre><code class="math">'
  else
    output = "<p>"
  end

  local todo = ""
  if state.todo then
    todo = "<span class=\"todo-status-" .. state.todo .. "\"></span>"
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
  table.insert(state.tag_params, text)

  return {
    output = "",
  }
end

---@param state table
---@return table
local function reset_link_location(_, _, state)
  state.link.location = {}
  return {
    output = "",
    keep_descending = true,
  }
end

---@param text string
---@param state table
---@return table
local function set_link_loction_file(text, _, state)
  state.link.location.file = text

  return {
    output = "",
    keep_descending = true,
  }
end

---@param text string
---@param node TSNode
---@param state table
---@return table
local function parse_paragraph_node(text, node, state)
  local type = node:parent():type()
  if type == "link_location" then
    state.link.location.text = text
  elseif type == "link_description" and state.link then
    state.link.description = text
  end

  return {
    output = "",
    keep_descending = true,
  }
end

---@param output table
---@param state table
---@return table
local function add_closing_paragraph_tags(output, state)
  if state.heading and state.heading > 0 then
    table.insert(output, "</h" .. state.heading .. ">\n")
    state.heading = 0
  elseif is_stack_empty(state, StackKey.LIST) then
    table.insert(output, "</li>\n")
  else
    table.insert(output, "</p>\n")
  end

  return output
end

---@param output table
---@param state table
---@return table
local function apply_ranged_tag_handlers(output, state)
  local name = state.tag_name
  local params = state.tag_params
  local content = state.tag_content

  local ranged_tag_handler = module.config.public.html.ranged_tag_handler[name] or
      module.private.ranged_tag_handler[name] or
      module.private.ranged_tag_handler["comment"]

  table.insert(output, ranged_tag_handler(params, content, state))

  state.tag_name = ""
  state.tag_params = {}
  state.tag_content = ""

  return output
end

module.load = function()
end

module.config.public = {
  html = {
    ranged_tag_handler = {}
  },
  -- Used by the exporter to know what extension to use
  -- when creating markdown files.
  -- The default is recommended, although you can change it.
  extension = "html",
}

module.private = {
  ranged_tag_handler = {
    ["code"] = function(params, content)
      local language = params[1] or ""
      return "\n<pre>\n<code class=\"" .. language .. "\">\n" .. content .. "\n</code>\n</pre>\n"
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
    ["spoiler"] = "span",
    ["verbatim"] = "pre",
    ["superscript"] = "sup",
    ["subscript"] = "sub",
    ["inline_math"] = { tag = "pre", class = "math" },
  },
}

--- @class core.export.html
module.public = {
  export = {
    init_state = init_state,
    functions = {
      ["_word"] = true,
      ["_space"] = true,
      ["_open"] = get_opening_tag,
      ["_close"] = get_closing_tag,
      ["_begin"] = "",
      ["_end"] = "",
      ["escape_sequence"] = keep_descending(),
      ["any_char"] = true,

      ["paragraph_segment"] = paragraph_segment,
      ["paragraph"] = parse_paragraph_node,

      ["heading1"] = heading(LinkType.HEADING1),
      ["heading2"] = heading(LinkType.HEADING2),
      ["heading3"] = heading(LinkType.HEADING3),
      ["heading4"] = heading(LinkType.HEADING4),
      ["heading5"] = heading(LinkType.HEADING5),
      ["heading6"] = heading(LinkType.HEADING6),


      ["unordered_list1"] = nest_tag("ul", 1, StackKey.LIST),
      ["unordered_list2"] = nest_tag("ul", 2, StackKey.LIST),
      ["unordered_list3"] = nest_tag("ul", 3, StackKey.LIST),
      ["unordered_list4"] = nest_tag("ul", 4, StackKey.LIST),
      ["unordered_list5"] = nest_tag("ul", 5, StackKey.LIST),
      ["unordered_list6"] = nest_tag("ul", 6, StackKey.LIST),

      ["ordered_list1"] = nest_tag("ol", 1, StackKey.LIST),
      ["ordered_list2"] = nest_tag("ol", 2, StackKey.LIST),
      ["ordered_list3"] = nest_tag("ol", 3, StackKey.LIST),
      ["ordered_list4"] = nest_tag("ol", 4, StackKey.LIST),
      ["ordered_list5"] = nest_tag("ol", 5, StackKey.LIST),
      ["ordered_list6"] = nest_tag("ol", 6, StackKey.LIST),

      ["quote1"] = nest_tag("blockquote", 1, StackKey.BLOCK_QUOTE),
      ["quote2"] = nest_tag("blockquote", 2, StackKey.BLOCK_QUOTE),
      ["quote3"] = nest_tag("blockquote", 3, StackKey.BLOCK_QUOTE),
      ["quote4"] = nest_tag("blockquote", 4, StackKey.BLOCK_QUOTE),
      ["quote5"] = nest_tag("blockquote", 5, StackKey.BLOCK_QUOTE),
      ["quote6"] = nest_tag("blockquote", 6, StackKey.BLOCK_QUOTE),

      ["tag_name"] = add_tag_name,
      ["tag_param"] = add_tag_param,
      ["tag_parameters"] = keep_descending({ tag_params = {} }),
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

      ["link_file_text"] = set_link_loction_file,
      ["link_location"] = reset_link_location,
      ["anchor_declaration"] = keep_descending({ link = {} }),
      ["anchor_definition"] = keep_descending({ link = {} }),
      ["link"] = keep_descending({ link = {} }),

      ["link_target_heading1"] = set_link_type(LinkType.HEADING1),
      ["link_target_heading2"] = set_link_type(LinkType.HEADING2),
      ["link_target_heading3"] = set_link_type(LinkType.HEADING3),
      ["link_target_heading4"] = set_link_type(LinkType.HEADING4),
      ["link_target_heading5"] = set_link_type(LinkType.HEADING5),
      ["link_target_heading6"] = set_link_type(LinkType.HEADING6),
      ["link_target_generic"] = set_link_type(LinkType.GENERIC),
      ["link_target_external_file"] = set_link_type(LinkType.EXTERNAL_FILE),
      ["link_target_url"] = set_link_type(LinkType.TARGET_URL),

      ["strong_carryover"] = "",
      ["weak_carryover"] = "",

      -- [UNSUPPORTED] Infirm Tags are not currently supported, TS parsing
      -- is returning unexpected ranges for .image tag, specically "http:"
      -- gets included as a param and then the rest of hte URL is moved to
      -- the following paragraph as content.
      ["infirm_tag"] = "",
    },

    recollectors = {
      ["paragraph_segment"] = add_closing_paragraph_tags,

      ["link"] = get_anchor_element("link"),
      ["anchor_definition"] = get_anchor_element("anchor_definition"),
      ["anchor_declaration"] = get_anchor_element("anchor_declaration"),

      ["generic_list"] = nested_tag_recollector(StackKey.LIST),
      ["quote"] = nested_tag_recollector(StackKey.BLOCK_QUOTE),

      ["heading1"] = add_closing_tag("</div>\n"),
      ["heading2"] = add_closing_tag("</div>\n"),
      ["heading3"] = add_closing_tag("</div>\n"),
      ["heading4"] = add_closing_tag("</div>\n"),
      ["heading5"] = add_closing_tag("</div>\n"),
      ["heading6"] = add_closing_tag("</div>\n"),

      ["ranged_verbatim_tag_end"] = apply_ranged_tag_handlers,

      ["single_footnote"] = recollect_footnote,
      ["multi_footnote"] = recollect_footnote,
    },

    cleanup = function()
    end,
  },
}

return module
