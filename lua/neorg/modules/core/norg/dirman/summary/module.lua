--[[
    DIRMAN SUMMARY
    module to generate a summary of a workspace inside a note 
--]]
require("neorg.modules.base")
require("neorg.modules")
require("neorg.external.helpers")
local log = require("neorg.external.log")
local module = neorg.modules.create("core.norg.dirman.summary")

module.setup = function()
    return {
        sucess = true,
        requires = { "core.norg.dirman", "core.neorgcmd" },
    }
end

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        ["generate-workspace-summary"] = {
            args = 0,
            condition = "norg",
            name = "dirman.summary",
        },
    })
end

module.config.public = {}

module.public = {}

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["dirman.summary"] = true,
    },
}
module.on_event = function(event)
    local dirman = module.required["core.norg.dirman"]
    if event.type == "core.neorgcmd.events.dirman.summary" then
        local dir = dirman.get_current_workspace()[1]
        local files = dirman.get_norg_files(dir)
        local output = vim.defaulttable()
        local function gen_string(tbl, name, all_parents, heading_level)
            local str = { heading_level .. " " .. name }
            if type(tbl) ~= "table" then
                return name
            end
            for i, v in ipairs(tbl) do
                tbl[i] = nil
                table.insert(str, "{:" .. all_parents .. tostring(v) .. ":}[" .. tostring(v) .. "]")
            end
            for subdir, path in pairs(tbl) do
                vim.list_extend(str, gen_string(path, subdir, all_parents .. subdir .. "/", heading_level .. "*"))
            end
            return str
        end
        for _, v in ipairs(files) do
            v = string.reverse(string.gsub(string.reverse(v), "gron.", "", 1))
            local path_list = vim.split(v, "/")
            local tbl = output
            for i, p in ipairs(path_list) do
                path_list[i] = nil
                if vim.tbl_isempty(path_list) then
                    table.insert(tbl, p)
                else
                    tbl = tbl[p]
                end
            end
        end
        local str = gen_string(output, "Index", "", "*")
        local index = dirman.get_index()
        dirman.open_file(dir, index)
        local tstree = vim.treesitter.get_parser(0)
        local buflc = vim.api.nvim_buf_line_count(0)
        local query = neorg.utils.ts_parse_query(
            "norg",
            [[ 
            (heading1 (heading1_prefix) title: (paragraph_segment) @title (#eq? @title "Index"))
        ]]
        )
        for _, tree in ipairs(tstree:parse()) do
            for _, match, _ in query:iter_matches(tree:root(), 0, 1, buflc) do
                for _, node in pairs(match) do
                    local parent = node:parent()
                    local start_row, _, end_row, _ = parent:range()
                    vim.api.nvim_buf_set_lines(0, start_row, end_row, true, str)
                end
                break
            end
            break
        end
    end
end
return module
