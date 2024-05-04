--[[
    file: Link-Tools-Module
    summary: Functions useful for grabbing link information from a file or buffer
    internal: true
    ---

This module provides an easy interface for querying information about the links in a buffer
or file.
--]]

local neorg = require("neorg.core")
local Path = require("pathlib")
local modules = neorg.modules

local module = modules.create("core.link-tools")

module.setup = function()
    return {
        success = true,
        requires = { "core.integrations.treesitter", "core.dirman", "core.dirman.utils", "core.queries.native" },
    }
end

local dirman_utils, treesitter
module.load = function()
    treesitter = module.required["core.integrations.treesitter"]
    dirman_utils = module.required["core.dirman.utils"]
end

---@class NodeText
---@field range Range
---@field text string

---@class Link
---@field file? NodeText
---@field type? NodeText
---@field text? NodeText
---@field range Range range of the entire link

module.public = {
    ---fetch all the links in the given buffer
    ---@param source number | string bufnr or full path to file
    ---@return Link[]
    get_links = function(source)
        local link_query_string = [[
            (link
              (link_location
                file: (_)* @file
                type: (_)* @type
                text: (_)* @text) @link_location)
        ]]

        local norg_parser
        local iter_src
        if type(source) == "string" then
            -- check if the file is open; use the buffer contents if it is
            ---@diagnostic disable-next-line: param-type-mismatch
            if vim.fn.bufexists(source) then
                source = vim.uri_to_bufnr(vim.uri_from_fname(source))
            else
                iter_src = io.open(source, "r"):read("*a")
                norg_parser = vim.treesitter.get_string_parser(iter_src, "norg")
            end
        end

        if type(source) == "number" then
            if source == 0 then
                source = vim.api.nvim_get_current_buf()
            end
            norg_parser = vim.treesitter.get_parser(source, "norg")
            iter_src = source
        end

        if not norg_parser then
            return {}
        end

        local norg_tree = norg_parser:parse()[1]
        local query = vim.treesitter.query.parse("norg", link_query_string)

        local links = {}

        for _, match in query:iter_matches(norg_tree:root(), iter_src) do
            local link = {}
            for id, node in pairs(match) do
                local name = query.captures[id]
                link[name] = {
                    text = treesitter.get_node_text(node, iter_src),
                    range = { node:range() },
                }
            end
            link.range = link.link_location.range
            link.link_location = nil
            table.insert(links, link)
        end

        return links
    end,

    ---Return the full path of the file this link points at. Accounting for workspace relative and
    -- file relative paths. simplifies links
    ---@param host_file string file the link is in (allows resolving relative paths)
    ---@param link Link
    ---@return PathlibPath?, boolean? # full file path
    where_does_this_link_point = function(host_file, link)
        local file_path
        if link.type and link.type.text == "/ " then
            file_path = link.text.text -- don't ask me why the parser does this
        else
            file_path = link.file and link.file.text
            if file_path then
                file_path = dirman_utils.expand_pathlib(file_path)
            else
                file_path = host_file
            end
        end

        local rel = false
        if file_path then
            file_path = Path.new(file_path)
            if file_path:is_relative() then
                rel = true
                file_path = Path(host_file):parent():child(tostring(file_path))
            end
        end

        return Path(file_path):resolve_copy(), rel
    end,
}

module.private = {}

return module
