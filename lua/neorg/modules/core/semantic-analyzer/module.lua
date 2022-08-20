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

        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
        local semantics = {}

        local function next_node(node)
            if node:child_count() > 0 then
                return node:child(0)
            elseif node:next_sibling() then
                return node:next_sibling()
            elseif node:parent() and node:parent():next_sibling() then
                return node:parent():next_sibling()
            else
                local parent = node:parent()

                while parent do
                    if parent:next_sibling() then
                        return parent:next_sibling()
                    end

                    parent = parent:parent()
                end

                return
            end
        end

        local node = document_root

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

    parse_node = function(buffer, prev, next, semantics)
        local ts = module.required["core.integrations.treesitter"]
        local ts_utils = ts.get_ts_utils()

        local function peek(node)
            return ts_utils.get_next_node(node, true, true)
        end

        local function parse_prefix(type)
            if vim.startswith(type, "heading") then
                local level = tonumber(type:sub(-1, -1))
                local title = ts.get_node_text(next):gsub("(%S)~\n", "%1 "):gsub("%s%s+", " ")

                neorg.lib.ensure_nested(semantics, buffer, "headings", level, title)
                semantics[buffer].headings[level][title] = {}
                -- TODO: Deal with duplicate heading names
                -- TODO: Deal with backlinks and references
            else
            end
        end

        neorg.lib.match(prev:type())({
            heading1_prefix = neorg.lib.wrap(parse_prefix, "heading1"),
            heading2_prefix = neorg.lib.wrap(parse_prefix, "heading2"),
            heading3_prefix = neorg.lib.wrap(parse_prefix, "heading3"),
            heading4_prefix = neorg.lib.wrap(parse_prefix, "heading4"),
            heading5_prefix = neorg.lib.wrap(parse_prefix, "heading5"),
            heading6_prefix = neorg.lib.wrap(parse_prefix, "heading6"),
            _ = function() end,
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
        --             ["A link to somewhere"] = {
        --                 type = "heading1",
        --                 reference = self.headings[1]["A link to somewhere"],
        --                 title = "Custom text for the link",
        --             },
        --         },
        --     },
        -- },
    }, -- A key(buffer)-value(table) pair describing the semantics of a document
}

return module
