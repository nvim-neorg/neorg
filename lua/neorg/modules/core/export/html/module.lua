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
local lib, modules = neorg.lib, neorg.modules

local module = modules.create("core.export.html")

module.setup = function()
  return {
    success = true,
    requires = {
      "core.integrations.treesitter",
    },
  }
end

local last_parsed_link_location = ""

local StackKey = {
  LIST = "list",
  BLOCK_QUOTE = "blockquote",
}

--> Generic Utility Functions

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

local function is_stack_empty(state, stack_key)
  return state.nested_tag_stacks[stack_key] and #state.nested_tag_stacks[stack_key] > 0
end

local function todo_item(type)
  return function()
    return {
      output = "",
      state = {
        todo = "undone",
      },
    }
  end
end


local function get_metadata_array_prefix(node, state)
  return node:parent():type() == "array" and string.rep(" ", state.indent) .. "- " or ""
end

local function handle_metadata_literal(text, node, state)
  -- If the parent is an array, we need to indent it and add the `- ` prefix. Otherwise, there will be a key right before which will take care of indentation
  return get_metadata_array_prefix(node, state) .. text .. "\n"
end

local function update_indent(value)
  return function(_, _, state)
    return {
      state = {
        indent = state.indent + value,
      },
    }
  end
end

--> Recollector Utility Functions

local function heading_function(level)
  return function()
    return {
      output = "<div>\n",
      keep_descending = true,
      state = {
        heading = level,
      },
    }
  end
end

local function add_closing_tag(tag, cleanup)
  return function(output, state)
    table.insert(output, tag)
    if cleanup then
      cleanup(state)
    end
    return output
  end
end

local function handle_metadata_composite_element(empty_element)
  return function(output, state, node)
    if vim.tbl_isempty(output) then
      return { get_metadata_array_prefix(node, state), empty_element, "\n" }
    end
    local parent = node:parent():type()
    if parent == "array" then
      -- If the parent is an array, we need to splice an extra `-` prefix to the first element
      output[1] = output[1]:sub(1, state.indent) .. "-" .. output[1]:sub(state.indent + 2)
    elseif parent == "pair" then
      -- If the parent is a pair, the first element should be on the next line
      output[1] = "\n" .. output[1]
    end
    return output
  end
end

local function anchor_recollector(output)
  return {
    "<a href=\"" .. last_parsed_link_location .. "\">",
    output[1],
    "</a>",
  }
end
---

module.load = function()
end

module.config.public = {
  html = {
    macro_handler = {}
  },
  -- Used by the exporter to know what extension to use
  -- when creating markdown files.
  -- The default is recommended, although you can change it.
  extension = "html",
}

module.private = {
  macro_handler = {
    ["code"] = function(params, content)
      local language = params[1] or ""
      return "\n<pre>\n<code class=\"" .. language .. "\">\n" .. content .. "\n</code>\n</pre>\n"
    end,

    ["comment"] = function(_, content)
      return "\n<!--\n" .. content .. "\n-->\n"
    end,
  },
}

--- @class core.export.html
module.public = {
  export = {
    init_state = function()
      return {
        todo = nil,
        weak_indent = 0,
        indent = 0,
        heading = 0,
        tag_indent = 0,
        tag_close = nil,
        ranged_tag_indentation_level = 0,
        is_url = false,
        footnote_count = 0,
        nested_tag_stacks = {},
      }
    end,

    functions = {

      -- TODO: ["single_footnote"] = true,

      ["_word"] = true,
      ["_space"] = true,
      -- TODO: ["_segment"] = true,

      ["paragraph_segment"] = function(_, _, state)
        local output = ""

        if state.heading and state.heading > 0 then
          output = "<h" .. state.heading .. ">"
        elseif is_stack_empty(state, StackKey.LIST) then
          output = "<li>"
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
      end,

      ["heading1"] = heading_function(1),
      ["heading2"] = heading_function(2),
      ["heading3"] = heading_function(3),
      ["heading4"] = heading_function(4),
      ["heading5"] = heading_function(5),
      ["heading6"] = heading_function(6),

      ["_open"] = function(_, node)
        local type = node:parent():type()

        if type == "bold" then
          return "<b>"
        elseif type == "italic" then
          return "<i>"
        elseif type == "underline" then
          return "<u>"
        elseif type == "strikethrough" then
          return "<s>"
        elseif type == "spoiler" then
          return "<span class=\"spoiler\">"
        elseif type == "verbatim" then
          return "<pre>"
        elseif type == "superscript" then
          return "<sup>"
        elseif type == "subscript" then
          return "<sub>"
        elseif type == "inline_comment" then
          return "<!-- "
        elseif type == "inline_math" and module.config.public.extensions["mathematics"] then
          return module.config.public.mathematics.inline["start"]
        end
      end,

      ["_close"] = function(_, node)
        local type = node:parent():type()

        if type == "bold" then
          return "</b>"
        elseif type == "italic" then
          return "</i>"
        elseif type == "underline" then
          return "</u>"
        elseif type == "strikethrough" then
          return "</s>"
        elseif type == "spoiler" then
          return "</span>" -- TODO
        elseif type == "verbatim" then
          return "</pre>"  -- TODO
        elseif type == "superscript" then
          return "</sup>"
        elseif type == "subscript" then
          return "</sub>"
        elseif type == "inline_comment" then
          return " -->"
        elseif type == "inline_math" and module.config.public.extensions["mathematics"] then
          return module.config.public.mathematics.inline["end"]
        end
      end,

      ["_begin"] = "",
      ["_end"] = "",

      ["link_file_text"] = function(text)
        return vim.uri_from_fname(text .. ".html"):sub(string.len("file://") + 1)
      end,

      ["link_target_url"] = function()
        return {
          state = {
            is_url = true,
          },
        }
      end,

      ["escape_sequence"] = function(text)
        local escaped_char = text:sub(-1)
        return escaped_char:match("%p") and text or escaped_char
      end,

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


      ["tag_name"] = function(text, _, _, _)
        return {
          output = "",
          state = {
            tag_name = text,
          },
        }
      end,

      ["tag_param"] = function(text, _, state)
        table.insert(state.tag_params, text)

        return {
          output = "",
        }
      end,

      ["tag_parameters"] = function()
        return {
          output = "",
          keep_descending = true,
          state = {
            tag_params = {},
          },
        }
      end,

      ["ranged_verbatim_tag_content"] = function(text, _)
        return {
          output = "",
          state = {
            tag_content = text,
          },
        }
      end,


      ["todo_item_done"] = todo_item("done"),
      ["todo_item_undone"] = todo_item("undone"),
      ["todo_item_pending"] = todo_item("pending"),
      ["todo_item_urgent"] = todo_item("urgent"),
      ["todo_item_cancelled"] = todo_item("cancelled"),
      ["todo_item_recurring"] = todo_item("recurring"),
      ["todo_item_on_hold"] = todo_item("on_hold"),
      ["todo_item_uncertain"] = todo_item("uncertain"),

      ["single_definition_prefix"] = function()
        return module.config.public.extensions["definition-nest_tags"] and ": "
      end,

      ["multi_definition_prefix"] = function(_, _, state)
        if not module.config.public.extensions["definition-nest_tags"] then
          return
        end

        return {
          output = ": ",
          state = {
            indent = state.indent + 2,
          },
        }
      end,

      ["multi_definition_suffix"] = function(_, _, state)
        if not module.config.public.extensions["definition-nest_tags"] then
          return
        end

        return {
          state = {
            indent = state.indent - 2,
          },
        }
      end,

      ["_prefix"] = function(_, node)
        return {
          state = {
            ranged_tag_indentation_level = ({ node:range() })[2],
          },
        }
      end,

      ["capitalized_word"] = function(text, node)
        if node:parent():type() == "insertion" then
          if text == "Image" then
            return "!["
          end
        end
      end,

      ["strong_carryover"] = "",
      ["weak_carryover"] = "",

      ["key"] = function(text, _, state)
        return string.rep(" ", state.indent) .. (text == "authors" and "author" or text)
      end,

      [":"] = ": ",

      ["["] = update_indent(2),
      ["]"] = update_indent(-2),
      ["{"] = update_indent(2),
      ["}"] = update_indent(-2),

      ["string"] = handle_metadata_literal,
      ["number"] = handle_metadata_literal,
      ["horizontal_line"] = "___",
    },

    recollectors = {
      ["paragraph_segment"] = function(output, state)
        if state.heading and state.heading > 0 then
          table.insert(output, "</h" .. state.heading .. ">\n")
          state.heading = 0
        elseif is_stack_empty(state, StackKey.LIST) then
          table.insert(output, "</li>\n")
        else
          table.insert(output, "</p>\n")
        end

        return output
      end,

      ["link_location"] = function(output, state)
        last_parsed_link_location = output[#output - 1]

        if state.is_url then
          state.is_url = false
          return output
        end

        table.insert(output, #output - 1, "#")
        output[#output - 1] = output[#output - 1]:lower():gsub("-", " "):gsub("%p+", ""):gsub("%s+", "-")

        return output
      end,

      ["link"] = anchor_recollector,
      ["anchor_definition"] = anchor_recollector,

      ["generic_list"] = nested_tag_recollector(StackKey.LIST),
      ["quote"] = nested_tag_recollector(StackKey.BLOCK_QUOTE),

      ["single_definition"] = function(output)
        return {
          output[2],
          output[3],
          output[1],
          output[4],
        }
      end,

      ["multi_definition"] = function(output)
        output[3] = output[3]:gsub("^\n+  ", "\n") .. output[1]
        table.remove(output, 1)

        return output
      end,

      -- TODO
      ["insertion"] = function(output)
        if output[1] == "![" then
          table.insert(output, 1, "\n")

          local split = vim.split(output[3], "/", { plain = true })
          table.insert(output, 3, (split[#split]:match("^(.+)%..+$") or split[#split]) .. "](")
          table.insert(output, ")\n")
        end

        return output
      end,

      ["heading1"] = add_closing_tag("</div>\n"),
      ["heading2"] = add_closing_tag("</div>\n"),
      ["heading3"] = add_closing_tag("</div>\n"),
      ["heading4"] = add_closing_tag("</div>\n"),
      ["heading5"] = add_closing_tag("</div>\n"),
      ["heading6"] = add_closing_tag("</div>\n"),

      ["object"] = handle_metadata_composite_element("{}"),
      ["array"] = handle_metadata_composite_element("[]"),
      ["ranged_verbatim_tag_end"] = function(output, state)
        local name = state.tag_name
        local params = state.tag_params
        local content = state.tag_content

        local macro_handler = module.config.public.html.macro_handler[name] or module.private.macro_handler[name] or
            module.private.macro_handler["comment"]

        table.insert(output, macro_handler(params, content, state))

        state.tag_name = ""
        state.tag_params = {}
        state.tag_content = ""

        return output
      end
    },

    cleanup = function()
      last_parsed_link_location = ""
    end,
  },
}

return module
