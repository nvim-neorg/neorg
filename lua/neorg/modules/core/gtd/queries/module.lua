--[[
Custom gtd queries, that respect the neorg GTD specs (:h neorg-gtd-format)

REQUIRES:
- core.norg.dirman              for file operations
- core.queries.native           to use queries and customize them
- core.integrations.treesitter  to use ts_utils

SUBMODULES:
* RETRIEVERS:
Exposes functions to retrieve useful stuff from gtd files
- get                           retrieve a table of { node, bufnr } for the type specified
- get_at_cursor                 retrieve the content under the cursor ({ node, bufnr}) for the type specified
- add_metadatas                 add metadatas to the content returned by `get`
* CREATORS:
Exposes functions to create stuff in files
- create                        create (task, project,...) in specified location in file
- get_end_project               get the end col of a metadata completed project node
- get_end_document_content      get the end col of the document content
- insert_tag                    insert a metadata in a specific location
* MODIFIERS:
Exposes functions to modify gtd stuff
- modify                        modify a specific node from a project or task
- update                        update a specific node from a project or task
- delete                        delete a specific node from a project or task
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
}

return module
