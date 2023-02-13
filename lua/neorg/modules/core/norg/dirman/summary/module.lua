--[[
    DIRMAN SUMMARY
    module to generate a summary of a workspace inside a note 
--]]
require("neorg.modules.base")
require("neorg.modules")

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

module.config.public = {
    -- The list of summaries, by default contains one inside the index file of a workspace.
    summaries = {
        {
            -- The file to include the summary in
            file = function()
                return module.required["core.norg.dirman"].get_index()
            end,
            -- The summary location, must be a top level heading.
            location = "* Index",
            -- File categories to include in the summary, if empty will include all notes
            categories = {},
        },
    },
}

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
            local str = heading_level .. name .. "\n"
            if type(tbl) ~= "table" then
                return name
            end
            for i, v in ipairs(tbl) do
                tbl[i] = nil
                str = str .. "{:" .. all_parents .. tostring(v) .. ":}[" .. tostring(v) .. "]\n"
            end
            for subdir, path in pairs(tbl) do
                str = str .. gen_string(path, subdir, all_parents .. subdir .. "/", heading_level .. "*")
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
        local str = gen_string(output, "", "", "*")
    end
end
return module
