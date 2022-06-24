--[[
    File: Journal
    Title: Journal module for Neorg
    Summary: Easily create files for a journal.
    ---
How to use this module:
This module creates four commands.
- `:Neorg journal today`
- `:Neorg journal yesterday`
- `:Neorg journal tomorrow`
With this commands you can open the config files for the dates.

- `Neorg journal custom`
This command requires a date as an argument.
The date should have to format yyyy-mm-dd.
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
    --- Opens a diary entry at the given time
    ---@param time number #The time to open the journal entry at as returned by `os.time()`
    ---@param custom_date_args table #A table with YYYY-mm-dd strings that specifies dates to open the diary at instead
    open_diary = function(time, custom_date_args)
        local custom_date = custom_date_args[1]
        local workspace = module.config.public.workspace
        local folder_name = module.config.public.journal_folder

        if custom_date then
            local year, month, day = custom_date:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")

            if not (year and month and day) then
                log.error("Wrong date format: use YYYY-mm-dd")
                return
            end

            time = os.time({
                year = year,
                month = month,
                day = day,
            })
        end

        local path = os.date(
            type(module.config.public.strategy) == "function"
                    and module.config.public.strategy(os.date("*t", time))
                or module.config.public.strategy,
            time
        )

        module.required["core.norg.dirman"].create_file(
            folder_name .. neorg.configuration.pathsep .. path,
            workspace or module.required["core.norg.dirman"].get_current_workspace()[1]
        )
    end,

    --- Opens a diary entry for tomorrow's date
    diary_tomorrow = function()
        module.private.open_diary(os.time() + 24 * 60 * 60)
    end,

    --- Opens a diary entry for yesterday's date
    diary_yesterday = function()
        module.private.open_diary(os.time() - 24 * 60 * 60)
    end,

    --- Opens a diary entry for today's date
    diary_today = function()
        module.private.open_diary()
    end,
}

module.config.public = {
    -- which workspace to use for the journal files, default is the current
    workspace = nil,
    -- the name for the folder in which the journal files are put
    journal_folder = "journal",

    -- The strategy to use to create directories
    -- can be "flat" (2022-03-02.norg), "nested" (2022/03/02.norg),
    -- a lua string with the format given to `os.date()` or a lua function
    -- that returns a lua string with the same format.
    strategy = "nested",

    -- TODO: Add templates
}

module.config.private = {
    strategies = {
        flat = "%Y-%m-%d.norg",
        nested = "%Y/%m/%d.norg",
    },
}

module.public = {
    version = "0.0.9",
}

module.load = function()
    if module.config.private.strategies[module.config.public.strategy] then
        module.config.public.strategy = module.config.private.strategies[module.config.public.strategy]
    end

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
                    tomorrow = {
                        args = 0,
                        name = "journal.tomorrow",
                        callback = module.private.diary_tomorrow,
                    },
                    yesterday = {
                        args = 0,
                        name = "journal.yesterday",
                        callback = module.private.diary_yesterday,
                    },
                    today = {
                        args = 0,
                        name = "journal.today",
                        callback = module.private.diary_today,
                    },
                    custom = {
                        args = 1,
                        name = "journal.custom",
                        callback = module.private.open_diary,
                        parameters = { os.time(), "args" },
                    }, -- format :yyyy-mm-dd
                },
            },
        },
    })
end

-- module.events.subscribed = {
--     ["core.neorgcmd"] = {
--         ["journal.yesterday"] = true,
--         ["journal.tomorrow"] = true,
--         ["journal.today"] = true,
--         ["journal.custom"] = true,
--     },
-- }

return module
