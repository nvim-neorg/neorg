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
    }
end

module.public = {
    --- Search for all $uuid tags and generate missing UUIDs for each node
    --- @param nodes table #A table of { node, bufnr }
    generate_missing_uuids = function(nodes, node_type)
        -- Construct a table of uuids/node/bufnr
        local uuids = vim.tbl_map(function(n)
            return {
                uuid = module.private.get_tag("uuid", { node = n[1], bufnr = n[2] }, false),
                node = n[1],
                bufnr = n[2],
            }
        end, nodes)

        -- Find the first node that dont have an uuid
        local node
        for _, _node in pairs(uuids) do
            if not _node.uuid then
                node = _node
                break
            end
        end

        if not node then
            return
        end

        local uuid = module.public.generate_uuid()
        local uuid_tag = module.private.get_tag("uuid", { node = node.node, bufnr = node.bufnr }, false)

        -- Re-get all tasks on current buffer and recursiverly call the function
        local function descend()
            vim.api.nvim_buf_call(node.bufnr, function()
                vim.cmd(" write ")
            end)
            nodes = module.public.get(node_type)
            module.public.generate_missing_uuids(nodes, node_type)
        end

        -- Generate the tag and recursively retry
        if not uuid_tag then
            if module.public.insert_tag({ node.node, node.bufnr }, uuid, "$uuid") then
                descend()
                return
            end
        end
    end,
}

module = utils.require(module, "helpers")
module = utils.require(module, "retrievers")
module = utils.require(module, "creators")
module = utils.require(module, "modifiers")

return module
