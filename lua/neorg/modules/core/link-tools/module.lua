--[[
    file: Link-Tools-Module
    summary: Functions useful for grabbing link information from a file or buffer
    internal: true
    ---

This module provides an easy interface for querying information about the links in a buffer
or file.
--]]

local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.link-tools")

module.setup = function()
    return {
        success = true,
        requires = { "core.integrations.treesitter", "core.dirman", "core.queries.native" },
    }
end

module.load = function()
    module.private.ts = module.required["core.integrations.treesitter"]
end

module.public = {
    ---fetch all the file links in the given buffer
    ---@param bufnr number
    ---@return table
    get_file_links_from_buf = function(bufnr)
        if bufnr == 0 then
            bufnr = vim.api.nvim_get_current_buf()
        end

        local nodes = module.private.ts.get_all_nodes("link_file_text", { buf = bufnr, ft = "norg" })
        local res = {}
        for _, node in ipairs(nodes) do
            table.insert(res, { module.private.ts.get_node_text(node), node:range() })
        end

        return res
    end,

    ---fetch all the file links in the given file
    ---@param file_path string
    ---@return table
    get_file_links_from_file = function(file_path)
        file_path = vim.fs.normalize(file_path)
        local nodes = module.private.ts.get_all_nodes_in_file("link_file_text", file_path)
        local res = {}

        for _, node in ipairs(nodes) do
            table.insert(res, { module.private.ts.get_node_text(node, file_path), node:range() })
        end

        return res
    end
}

module.private = {}

return module
