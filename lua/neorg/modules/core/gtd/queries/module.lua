--[[
Custom gtd queries, that respect the neorg GTD specs (:h neorg-gtd-format)

REQUIRES:
- core.norg.dirman              for file operations
- core.queries.native           to use queries and customize them
- core.integrations.treesitter  to use ts_utils

SUBMODULES:
* RETRIEVERS:
Exposes functions to retrieve useful stuff from gtd files
- get               retrieve a table of { node, bufnr } for the type specified
- get_at_cursor     retrieve the content under the cursor ({ node, bufnr}) for the type specified
- add_metadatas     add metadatas to the content returned by `get`
* CREATORS:
Exposes functions to create stuff in files
- create                        create (task, project,...) in specified location in file
- get_end_project               get the end col of a metadata completed project node
- get_end_document_content      get the end col of the document content
* MODIFIERS:
Exposes functions to modify gtd stuff

--]]

require("neorg.modules.base")
local module = neorg.modules.create("core.gtd.queries")
local utils = require("neorg.external.helpers")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.queries.native",
            "core.integrations.treesitter",
        },
        imports = {
            "helpers",
            "retrievers",
            "creators",
            "modifiers",
        },
    }
end

module.public = {

    --- Update a specific `node` with `type`.
    --- Note: other nodes don't get updated ! If you want to update all nodes, just redo a module.required["core.gtd.queries"].get
    --- @param node table #A task/project with metadatas
    --- @param node_type string
    update = function(node, node_type)
        if not vim.tbl_contains({ "task", "project" }, node_type) then
            log.error("Incorrect node_type")
            return
        end

        -- Get all nodes from same bufnr
        local nodes = module.public.get(node_type .. "s", { bufnr = node.bufnr })
        local originally_extracted = type(node.content) == "string"
        nodes = module.public.add_metadata(nodes, node_type, { extract = originally_extracted })

        local found_node = vim.tbl_filter(function(n)
            return n.position == node.position
        end, nodes)

        if #found_node == 0 then
            log.error("An error occured in updating node")
            return
        end

        return found_node[1]
    end,
}

return module
