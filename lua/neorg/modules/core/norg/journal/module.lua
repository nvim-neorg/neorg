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
- `:Neorg journal toc update`
This command creates or updates a TOC file containing all the entries located in the journal folder, named after the workspace index.
- `:Neorg journal toc open`
This command opens the TOC file without updating it.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.journal")
local log = require("neorg.external.log")

module.examples = {
    ["Changing TOC format to divide year in quarters"] = function()
        -- In your ["core.norg.journal"] options, change toc_format to a function like this:

        require("neorg").setup({
            load = {
                -- ...
                ["core.norg.journal"] = {
                    config = {
                        -- ...
                        toc_format = function(entries)
                            -- Convert the entries into a certain format

                            local output = {}
                            local current_year
                            local current_quarter
                            local last_quarter
                            local current_month
                            for _, entry in ipairs(entries) do
                                -- Don't print the year if it hasn't changed
                                if not current_year or current_year < entry[1] then
                                    current_year = entry[1]
                                    table.insert(output, "* " .. current_year)
                                end

                                -- Check to which quarter the current month corresponds to
                                if entry[2] <= 3 then
                                    current_quarter = 1
                                elseif entry[2] <= 6 then
                                    current_quarter = 2
                                elseif entry[2] <= 9 then
                                    current_quarter = 3
                                else
                                    current_quarter = 4
                                end

                                -- If the current month corresponds to another quarter, print it
                                if current_quarter ~= last_quarter then
                                    table.insert(output, "** Quarter " .. current_quarter)
                                    last_quarter = current_quarter
                                end

                                -- Don't print the month if it hasn't changed
                                if not current_month or current_month < entry[2] then
                                    current_month = entry[2]
                                    table.insert(output, "*** Month " .. current_month)
                                end

                                -- Prints the file link
                                table.insert(output, entry[4] .. string.format("[%s]", entry[5]))
                            end

                            return output
                        end,
                        -- ...
                    },
                },
            },
        })
    end,
}

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.keybinds",
            "core.neorgcmd",
            "core.integrations.treesitter",
        },
    }
end

module.private = {
    --- Opens a diary entry at the given time
    ---@param time number #The time to open the journal entry at as returned by `os.time()`
    ---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the diary at instead
    open_diary = function(time, custom_date)
        local workspace = module.config.public.workspace or module.required["core.norg.dirman"].get_current_workspace()[1]
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

        local workspace_path = module.required["core.norg.dirman"].get_workspace(workspace)

        local journal_file_exists = module.required["core.norg.dirman"].file_exists(
            workspace_path .. "/" .. folder_name .. neorg.configuration.pathsep .. path
        )

        module.required["core.norg.dirman"].create_file(folder_name .. neorg.configuration.pathsep .. path, workspace)

        if
            not journal_file_exists
            and module.config.public.use_template
            and module.required["core.norg.dirman"].file_exists(workspace_path .. "/" .. folder_name .. "/" .. template_name)
        then
            vim.cmd("0read " .. workspace_path .. "/" .. folder_name .. "/" .. template_name .. "| w")
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

    --- Opens the toc file
    open_toc = function()
        local workspace = module.config.public.workspace
            or module.required["core.norg.dirman"].get_current_workspace()[1]
        local index = neorg.modules.get_module_config("core.norg.dirman").index
        local folder_name = module.config.public.journal_folder

        -- If the toc exists, open it, if not, create it
        if module.required["core.norg.dirman"].file_exists(folder_name .. neorg.configuration.pathsep .. index) then
            module.required["core.norg.dirman"].open_file(
                workspace,
                folder_name .. neorg.configuration.pathsep .. index
            )
        else
            module.private.create_toc()
        end
    end,

    --- Creates or updates the toc file
    create_toc = function()
        local workspace = module.config.public.workspace
            or module.required["core.norg.dirman"].get_current_workspace()[1]
        local index = neorg.modules.get_module_config("core.norg.dirman").index
        local folder_name = module.config.public.journal_folder

        -- Each entry is a table that contains tables like { yy, mm, dd, link, title }
        local toc_entries = {}

        -- Get a filesystem handle for the files in the journal folder
        -- path is for each subfolder
        local get_fs_handle = function(path)
            path = path or ""
            local handle = vim.loop.fs_scandir(folder_name .. neorg.configuration.pathsep .. path)

            if type(handle) ~= "userdata" then
                error(neorg.lib.lazy_string_concat("Failed to scan directory '", workspace, path, "': ", handle))
            end

            return handle
        end

        -- Gets the title from the metadata of a file, must be called in a vim.schedule
        local get_title = function(file)
            local buffer = vim.fn.bufadd(folder_name .. neorg.configuration.pathsep .. file)
            local meta = module.required["core.integrations.treesitter"].get_document_metadata(buffer)
            local title = meta["title"]
            return title
        end

        vim.loop.fs_scandir(folder_name .. neorg.configuration.pathsep, function(_, handle)
            while true do
                -- Name corresponds to either a YYYY-mm-dd.norg file, or just the year ("nested" strategy)
                local name, type = vim.loop.fs_scandir_next(handle)

                if not name then
                    break
                end

                -- Handle nested entries
                if type == "directory" then
                    local years_handle = get_fs_handle(name)
                    while true do
                        -- mname is the month
                        local mname, mtype = vim.loop.fs_scandir_next(years_handle)

                        if not mname then
                            break
                        end

                        if mtype == "directory" then
                            local months_handle = get_fs_handle(name .. neorg.configuration.pathsep .. mname)
                            while true do
                                -- dname is the day
                                local dname, dtype = vim.loop.fs_scandir_next(months_handle)

                                if not dname then
                                    break
                                end

                                -- If it's a .norg file, also ensure it is a day entry
                                if dtype == "file" and string.match(dname, "%d%d%.norg") then
                                    -- Split the file name
                                    local file = vim.split(dname, ".", { plain = true })

                                    vim.schedule(function()
                                        -- Get the title from the metadata, else, it just defaults to the name of the file
                                        local title = get_title(
                                            name
                                                .. neorg.configuration.pathsep
                                                .. mname
                                                .. neorg.configuration.pathsep
                                                .. dname
                                        ) or file[1]

                                        -- Insert a new entry
                                        table.insert(toc_entries, {
                                            tonumber(name),
                                            tonumber(mname),
                                            tonumber(file[1]),
                                            "{:$"
                                                .. neorg.configuration.pathsep
                                                .. module.config.public.journal_folder
                                                .. neorg.configuration.pathsep
                                                .. name
                                                .. neorg.configuration.pathsep
                                                .. mname
                                                .. neorg.configuration.pathsep
                                                .. file[1]
                                                .. ":}",
                                            title,
                                        })
                                    end)
                                end
                            end
                        end
                    end
                end

                -- Handles flat entries
                -- If it is a .norg file, but it's not any user generated file.
                -- The match is here to avoid handling files made by the user, like a template file, or
                -- the toc file
                if type == "file" and string.match(name, "%d+-%d+-%d+%.norg") then
                    -- Split yyyy-mm-dd to a table
                    local file = vim.split(name, ".", { plain = true })
                    local parts = vim.split(file[1], "-")

                    -- Convert the parts into numbers
                    for k, v in pairs(parts) do
                        parts[k] = tonumber(v)
                    end

                    vim.schedule(function()
                        -- Get the title from the metadata, else, it just defaults to the name of the file
                        local title = get_title(name) or parts[3]

                        -- And insert a new entry that corresponds to the file
                        table.insert(toc_entries, {
                            parts[1],
                            parts[2],
                            parts[3],
                            "{:$"
                                .. neorg.configuration.pathsep
                                .. module.config.public.journal_folder
                                .. neorg.configuration.pathsep
                                .. file[1]
                                .. ":}",
                            title,
                        })
                    end)
                end
            end

            vim.schedule(function()
                -- Gets a default format for the entries
                local format = module.config.public.toc_format
                    or function(entries)
                        local months_text = {
                            "January",
                            "February",
                            "March",
                            "April",
                            "May",
                            "June",
                            "July",
                            "August",
                            "September",
                            "October",
                            "November",
                            "December",
                        }
                        -- Convert the entries into a certain format to be written
                        local output = {}
                        local current_year
                        local current_month
                        for _, entry in ipairs(entries) do
                            -- Don't print the year and month if they haven't changed
                            if not current_year or current_year < entry[1] then
                                current_year = entry[1]
                                table.insert(output, "* " .. current_year)
                            end
                            if not current_month or current_month < entry[2] then
                                current_month = entry[2]
                                table.insert(output, "** " .. months_text[current_month])
                            end

                            -- Prints the file link
                            table.insert(output, entry[4] .. string.format("[%s]", entry[5]))
                        end

                        return output
                    end

                module.required["core.norg.dirman"].create_file(
                    folder_name .. neorg.configuration.pathsep .. index,
                    workspace or module.required["core.norg.dirman"].get_current_workspace()[1]
                )

                -- The current buffer now must be the toc file, so we set our toc entries there
                vim.api.nvim_buf_set_lines(0, 0, -1, false, format(toc_entries))
                vim.cmd("w")
            end)
        end)
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

    -- formatter function used to generate the toc file
    -- receives a table that contains tables like { yy, mm, dd, link, title }
    -- must return a table of strings
    toc_format = nil,
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
        journal = {
            min_args = 1,
            max_args = 2,
            subcommands = {
                tomorrow = { args = 0, name = "journal.tomorrow" },
                yesterday = { args = 0, name = "journal.yesterday" },
                today = { args = 0, name = "journal.today" },
                custom = { args = 1, name = "journal.custom" }, -- format :yyyy-mm-dd
                template = { args = 0, name = "journal.template" },
                toc = {
                    args = 1,
                    name = "journal.toc",
                    condition = "norg",
                    subcommands = {
                        open = { args = 0, name = "journal.toc.open" },
                        update = { args = 0, name = "journal.toc.update" },
                    },
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
        elseif event.split_type[2] == "journal.toc.open" then
            module.private.open_toc()
        elseif event.split_type[2] == "journal.toc.update" then
            module.private.create_toc()
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
        ["journal.toc.update"] = true,
        ["journal.toc.open"] = true,
    },
}

return module
