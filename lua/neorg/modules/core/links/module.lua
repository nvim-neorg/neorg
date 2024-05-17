--[[
    file: Links
    title: Find links/target in the buffer
    description: Utility module to handle links/link targets in the buffer
    internal: true
    ---

This module provides utility functions that are used to find links and their targets in the buffer.
--]]

local neorg = require("neorg.core")
local lib, modules = neorg.lib, neorg.modules

local module = modules.create("core.links")

module.setup = function()
    return {
        success = true,
    }
end

---@class core.links
module.public = {
    -- TS query strings for different link targets
    ---@param link_type "generic" | "definition" | "footnote" | string
    get_link_target_query_string = function(link_type)
        return lib.match(link_type)({
            generic = [[
                [(_
                  [(strong_carryover_set
                     (strong_carryover
                       name: (tag_name) @tag_name
                       (tag_parameters) @title
                       (#eq? @tag_name "name")))
                   (weak_carryover_set
                     (weak_carryover
                       name: (tag_name) @tag_name
                       (tag_parameters) @title
                       (#eq? @tag_name "name")))]?
                  title: (paragraph_segment) @title)
                 (inline_link_target
                   (paragraph) @title)]
            ]],

            [{ "definition", "footnote" }] = string.format(
                [[
                (%s_list
                    (strong_carryover_set
                          (strong_carryover
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")))?
                    .
                    [(single_%s
                       (weak_carryover_set
                          (weak_carryover
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")))?
                       (single_%s_prefix)
                       title: (paragraph_segment) @title)
                     (multi_%s
                       (weak_carryover_set
                          (weak_carryover
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")))?
                        (multi_%s_prefix)
                          title: (paragraph_segment) @title)])
                ]],
                lib.reparg(link_type, 5)
            ),
            _ = string.format(
                [[
                    (%s
                      [(strong_carryover_set
                         (strong_carryover
                           name: (tag_name) @tag_name
                           (tag_parameters) @title
                           (#eq? @tag_name "name")))
                       (weak_carryover_set
                         (weak_carryover
                           name: (tag_name) @tag_name
                           (tag_parameters) @title
                           (#eq? @tag_name "name")))]?
                      (%s_prefix)
                      title: (paragraph_segment) @title)
                ]],
                lib.reparg(link_type, 2)
            ),
        })
    end,
}

return module
