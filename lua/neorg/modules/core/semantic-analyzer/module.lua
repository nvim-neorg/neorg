--[[
---
This module provides an interface to query semantically analyzed elements of a document.

It behaves somewhat like an LSP interface, where you can query:
- The definition of an object (like a heading)
- Links (functional links, dead links)
- References to an object
- Incorrect date/time syntax
- Formatting errors (?)

### Why not an LSP?
An LSP is actually in the works, but there is more to this module than just being an LSP alternative.
Exporting files, for instance, sometimes requires semantic information about the current document.
*Requiring* an LSP in order to query this semantic info is not a good call. It's much easier to make
a semantic analyzer in lua as well, cause we have treesitter quite literally builtin.

### TODO
- Send off this computation to another neovim instance (`nvim --headless --listen 127.0.0.1:myport`)
- Create a client/server model to make these processes communicate
- When communicating, do it incrementally with a callback (i.e. as every singular node is parsed) versus
  sending back the whole result after the fact. This will help in incrementally displaying some diagnostics
  without needing to parse every single file out the gate.
- Set up a file watcher to reparse files?
--]]

local module = neorg.modules.create("core.semantic-analyzer")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            -- "core.autocommands", // New modules don't use this anymore - old ones will soon be refactored too
        },
    }
end

module.load = function()
    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*.norg",
        callback = function(info)
            log.warn(module.private.parse_file(info.buf))
        end,
    })
end

module.private = {
    parse_file = function(buffer)
        local document_root = module.required["core.integrations.treesitter"].get_document_root(buffer)

        if not document_root then
            return
        end

        local semantics = {}

        --- Retrieves the next node just to the right of the current one.
        ---@param node userdata #The start node
        ---@return userdata #The next sibling node
        local function next_node(node)
            -- NOTE: This function is an attempt to essentially emulate a
            -- TSTreeCursor. Apparently that's not exposed in the Neovim treesiter
            -- api :(
            local line_end, char_end = node:end_()

            ::retry::
            local line = vim.api.nvim_buf_get_lines(buffer, line_end, line_end + 1, false)[1]

            if not line then
                return
            end

            -- If we've moved our "cursor" past the current line
            -- then move to the next line
            if char_end + 1 > line:len() then
                line_end = line_end + 1
                char_end = -1
            end

            -- Get the node at the current "cursor"'s position
            local ret = document_root:descendant_for_range(line_end, char_end + 1, line_end, char_end + 1)

            -- If we encountered some wacky node that is a parent
            -- of what we would expect then move the "cursor" right and
            -- try again. This prevents us from accidentally backtracking
            -- and falling into an infinite loop.
            if ret:start() ~= line_end then
                char_end = char_end + 1
                goto retry
            end

            return ret
        end

        -- Get the first node in the document (that isn't the `document` node)
        local first_non_blank = (vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1] or ""):match("^%s*"):len()
        local node = document_root:descendant_for_range(0, first_non_blank, 0, first_non_blank)

        while true do
            local next = next_node(node)

            if not next then
                break
            end

            semantics = module.private.parse_node(buffer, node, next, semantics)
            node = next
        end

        return semantics
    end,

    parse_node = function(buffer, prev, _next, semantics)
        local ts = module.required["core.integrations.treesitter"]

        local function parse_prefix(type)
            local title_node = prev:next_named_sibling()

            if not title_node then
                return
            end

            local level = tonumber(type:sub(-1, -1))
            local title = ts.get_node_text(title_node):gsub("(%S)~\n", "%1 "):gsub("%s", ""):lower()

            if vim.startswith(type, "heading") then
                neorg.lib.ensure_nested(semantics, buffer, "headings", level, title)
                local heading = semantics[buffer].headings[level][title]

                if heading[#heading] and not heading[#heading].range then
                    heading[#heading].range = ts.get_node_range(prev:parent())
                else
                    table.insert(semantics[buffer].headings[level][title], {
                        range = ts.get_node_range(prev:parent()),
                    })
                end
            elseif type == "footnote" or type == "definition" then
                local type_with_s = table.concat{type, "s"}

                neorg.lib.ensure_nested(semantics, buffer, type_with_s, title)

                local definition = semantics[buffer][type_with_s][title]

                local definition_content = prev:parent():field("content")
                local row_start, col_start = definition_content[1]:start()
                local row_end, col_end = definition_content[#definition_content]:end_()

                if definition[#definition] and not definition[#definition].range then
                    definition[#definition].range = ts.get_node_range(prev:parent())
                    definition[#definition].content_range = {
                        row_start = row_start,
                        column_start = col_start,
                        row_end = row_end,
                        column_end = col_end,
                    }
                else
                    table.insert(semantics[buffer][type_with_s][title], {
                        range = ts.get_node_range(prev:parent()),
                        content_range = {
                            row_start = row_start,
                            column_start = col_start,
                            row_end = row_end,
                            column_end = col_end,
                        },
                    })
                end
            end
        end

        local function parse_link(link)
            local parsed_link = module.required["core.integrations.treesitter"].parse_link(link, buffer)
            local type, level = parsed_link.link_type:match("^([^%d]+)(%d?)$")
            level = level and tonumber(level)

            local trimmed_link_location_text = parsed_link.link_location_text:gsub("%s", ""):lower()

            local function try_create_nestable_reference(category, index)
                return function()
                    neorg.lib.ensure_nested(semantics, buffer, category, index)

                    if semantics[buffer][category][index][trimmed_link_location_text] then
                        return semantics[buffer][category][index][trimmed_link_location_text][1]
                    end

                    semantics[buffer][category][index][trimmed_link_location_text] = {
                        {
                            references = {},
                        },
                    }
                    return semantics[buffer][category][index][trimmed_link_location_text][1]
                end
            end

            local function try_create_rangeable_modifier_reference(category)
                return function()
                    neorg.lib.ensure_nested(semantics, buffer, category)

                    if semantics[buffer][category][trimmed_link_location_text] then
                        return semantics[buffer][category][trimmed_link_location_text][1]
                    end

                    semantics[buffer][category][trimmed_link_location_text] = {
                        {
                            references = {},
                        },
                    }
                    return semantics[buffer][category][trimmed_link_location_text][1]
                end
            end

            local link_address

            do
                if level then
                    neorg.lib.ensure_nested(
                        semantics,
                        buffer,
                        "links",
                        parsed_link.link_file_text or "",
                        type,
                        level,
                        trimmed_link_location_text
                    )

                    link_address =
                        semantics[buffer].links[parsed_link.link_file_text or ""][type][level][trimmed_link_location_text]
                else
                    neorg.lib.ensure_nested(
                        semantics,
                        buffer,
                        "links",
                        parsed_link.link_file_text or "",
                        type,
                        trimmed_link_location_text
                    )

                    link_address =
                        semantics[buffer].links[parsed_link.link_file_text or ""][type][trimmed_link_location_text]
                end
            end

            table.insert(link_address, {
                type = parsed_link.link_type,
                title = parsed_link.link_description,
                reference = neorg.lib.match(parsed_link.link_type)({
                    heading1 = try_create_nestable_reference("headings", 1),
                    heading2 = try_create_nestable_reference("headings", 2),
                    heading3 = try_create_nestable_reference("headings", 3),
                    heading4 = try_create_nestable_reference("headings", 4),
                    heading5 = try_create_nestable_reference("headings", 5),
                    heading6 = try_create_nestable_reference("headings", 6),
                    definition = try_create_rangeable_modifier_reference("definitions"),
                    footnote = try_create_rangeable_modifier_reference("footnotes"),
                    _ = nil,
                }),
                range = ts.get_node_range(link),
            })

            -- TODO: Remove the reliance on headings and make
            -- backreferences work with other stuff like definition etc.
            -- Just make sure not to treat urls and the like as backlinks!
            if vim.startswith(type, "heading") then
                neorg.lib.ensure_nested(
                    semantics,
                    buffer,
                    "headings",
                    level or 1,
                    trimmed_link_location_text,
                    1,
                    "references",
                    parsed_link.link_file_text or ""
                )
                table.insert(
                    semantics[buffer].headings[level or 1][trimmed_link_location_text][1].references[parsed_link.link_file_text or ""],
                    link_address
                )
            else
                local type_with_s = table.concat{type, "s"}

                neorg.lib.ensure_nested(
                    semantics,
                    buffer,
                    type_with_s,
                    trimmed_link_location_text,
                    1,
                    "references",
                    parsed_link.link_file_text or ""
                )
                table.insert(
                    semantics[buffer][type_with_s][trimmed_link_location_text][1].references[parsed_link.link_file_text or ""],
                    link_address
                )
            end
        end

        neorg.lib.match(prev:type())({
            heading1_prefix = neorg.lib.wrap(parse_prefix, "heading1"),
            heading2_prefix = neorg.lib.wrap(parse_prefix, "heading2"),
            heading3_prefix = neorg.lib.wrap(parse_prefix, "heading3"),
            heading4_prefix = neorg.lib.wrap(parse_prefix, "heading4"),
            heading5_prefix = neorg.lib.wrap(parse_prefix, "heading5"),
            heading6_prefix = neorg.lib.wrap(parse_prefix, "heading6"),
            [{ "single_definition_prefix", "multi_definition_prefix" }] = neorg.lib.wrap(parse_prefix, "definition"),
            [{ "single_footnote_prefix", "multi_footnote_prefix" }] = neorg.lib.wrap(parse_prefix, "footnote"),
            _ = function()
                if vim.startswith(prev:type(), "link_target_") then
                    return parse_link(prev:parent():parent())
                end
            end,
        })

        return semantics
    end,

    semantics = {
        -- [1] = { -- Buffer ID
        --     -- For e.g. things tagged with `#name`
        --     anonymous = {},
        --     headings = {
        --         [2] = { -- Level 2 heading
        --             ["My Heading"] = {},
        --             ["My Duplicate Heading"] = { -- For when there are duplicates
        --                 { -- These are represented in the same order they were declared in the doc
        --                     some_data = {},
        --                 },
        --                 {
        --                     some_other_data = {},
        --                 },
        --             },
        --         },
        --     },
        --     definitions = {},

        --     links = {
        --         [""] = {}, -- For the current file
        --         ["OtherFile"] = {
        --             ["A link to somewhere"] = { -- For when there are duplicates
        --                 {
        --                      type = "heading1",
        --                      reference = self.headings[1]["A link to somewhere"],
        --                      title = "Custom text for the link",
        --                      range = {},
        --                 },
        --             },
        --         },
        --     },
        -- },
    }, -- A key(buffer)-value(table) pair describing the semantics of a document
}

return module
