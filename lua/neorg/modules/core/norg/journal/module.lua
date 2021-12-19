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
    open_diary = function(date)
        local workspace = module.config.public.workspace
        local folder_name = module.config.public.journal_folder

        local year, month, day = date:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
        if not year or not month or not day then
            log.error("Wrong date format: use YYYY-mm-dd")
            return
        end

        if module.config.public.use_folders then
            module.required["core.norg.dirman"].create_file(
                folder_name .. "/" .. year .. "/" .. month .. "/" .. day .. ".norg",
                workspace
            )
        else
            module.required["core.norg.dirman"].create_file(folder_name .. "/" .. date .. ".norg", workspace)
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
    -- which workspace to use for the journal files, default is the current
    workspace = nil,
    -- the name for the folder in which the journal files are put
    journal_folder = "/journal/",
    -- wheter to use folders for years and months
    use_folders = true,
}

module.public = {
    version = "0.0.9",
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
