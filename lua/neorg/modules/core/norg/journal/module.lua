--[[
JOURNAL
This module will allow you to write a basic journal in neorg.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.journal")
local log = require("neorg.external.log")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.keybinds",
            "core.neorgcmd",
        },
    }
end

module.private = {
    open_diary = function(date)
        local workspace
        local folder
        local folder_name = module.config.public.journal_folder
        if not module.config.public.workspace then
            workspace = module.required["core.norg.dirman"].get_current_workspace()[2]
            folder = workspace .. "/" .. folder_name
        else
            workspace = module.required["core.norg.dirman"].get_workspace(module.config.public.workspace)
            folder = workspace .. folder_name
        end
        if not string.match(date, "^%d%d%d%d%-%d%d%-%d%d$") then
            log.error("Wrong date format: use yyyy-mm-dd")
            return
        end
        local year = string.sub(date, 1, 4)
        local month = string.sub(date, 6, 7)
        local day = string.sub(date, 9, 10)
        if module.config.public.use_folders then
            vim.cmd([[e ]] .. folder .. year .. "/" .. month .. "/" .. day .. ".norg")
        else
            vim.cmd([[e ]] .. folder .. "/" .. date .. ".norg")
        end
    end,

    diary_tomorrow = function()
        local date = os.date("%Y-%m-%d", os.time() + 24 * 60 * 60)
        module.private.open_diary(date)
    end,

    diary_yesterday = function()
        local date = os.date("%Y-%m-%d", os.time() - 24 * 60 * 60)
        module.private.open_diary(date)
    end,

    diary_today = function()
        local date = os.date("%Y-%m-%d", os.time())
        module.private.open_diary(date)
    end,
}

module.config.public = {
    workspace = nil,
    journal_folder = "/journal/",
    use_folders = true, -- if true -> /2021/07/23
}

module.public = {
    version = "0.1",
}

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            journal = {
                tomorrow = {},
                yesterday = {},
                today = {},
                custom = {},
            },
        },
        data = {
            journal = {
                min_args = 1,
                max_args = 2,
                subcommands = {
                    tomorrow = { args = 0, name = "journal.tomorrow" },
                    yesterday = { args = 0, name = "journal.yesterday" },
                    today = { args = 0, name = "journal.today" },
                    custom = { args = 1, name = "journal.custom" }, -- format :yyyy-mm-dd
                },
            },
        },
    })
end

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        if event.split_type[2] == "journal.tomorrow" then
            module.private.diary_tomorrow()
        elseif event.split_type[2] == "journal.yesterday" then
            module.private.diary_yesterday()
        elseif event.split_type[2] == "journal.custom" then
            module.private.open_diary(event.content[1])
        elseif event.split_type[2] == "journal.today" then
            module.private.diary_today()
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["journal.yesterday"] = true,
        ["journal.tomorrow"] = true,
        ["journal.today"] = true,
        ["journal.custom"] = true,
    },
}

return module
