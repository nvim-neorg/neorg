--[[
    File: Journal
    Title: Journal module for Neorg
    Summary: Easily create files for a journal.
    ---
How to use this module:
This module creates five commands.
- `:Neorg journal today`
- `:Neorg journal yesterday`
- `:Neorg journal tomorrow`
With this commands you can open the config files for the dates.

- `Neorg journal custom`
This command requires a date as an argument.
The date should have to format yyyy-mm-dd.

- `:Neorg journal template`
This command creates a template file which will be used whenever a new journal entry is created.
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
    ---@param custom_date string #A YYYY-mm-dd string that specifies a date to open the diary at instead
    open_diary = function(time, custom_date)
        local workspace = module.config.public.workspace
        local folder_name = module.config.public.journal_folder
        local template_name = module.config.public.template_name

        if custom_date then
            local year, month, day = custom_date:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")

            if not year or not month or not day then
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
            type(module.config.public.strategy) == "function" and module.config.public.strategy(os.date("*t", time))
                or module.config.public.strategy,
            time
        )

        local journal_file_exists = false
        if module.required["core.norg.dirman"].file_exists(folder_name .. neorg.configuration.pathsep .. path) then
            journal_file_exists = true
        end

        module.required["core.norg.dirman"].create_file(
            folder_name .. neorg.configuration.pathsep .. path,
            workspace or module.required["core.norg.dirman"].get_current_workspace()[1]
        )

        if
            not journal_file_exists
            and module.config.public.use_template
            and module.required["core.norg.dirman"].file_exists(folder_name .. "/" .. template_name)
        then
            vim.cmd("0read " .. folder_name .. "/" .. template_name .. "| w")
        end
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

    --- Creates a template file
    create_template = function()
        local workspace = module.config.public.workspace
        local folder_name = module.config.public.journal_folder
        local template_name = module.config.public.template_name

        module.required["core.norg.dirman"].create_file(
            folder_name .. neorg.configuration.pathsep .. template_name,
            workspace or module.required["core.norg.dirman"].get_current_workspace()[1]
        )
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

    -- the name of the template file
    template_name = "template.norg",
    -- use your journal_folder template
    use_template = true,
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
                template = {},
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
                    template = { args = 0, name = "journal.template" },
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
            module.private.open_diary(nil, event.content[1])
        elseif event.split_type[2] == "journal.today" then
            module.private.diary_today()
        elseif event.split_type[2] == "journal.template" then
            module.private.create_template()
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["journal.yesterday"] = true,
        ["journal.tomorrow"] = true,
        ["journal.today"] = true,
        ["journal.custom"] = true,
        ["journal.template"] = true,
    },
}

return module
