--[[
    File: Neorgcmd-Module
    Title: Neorgcmd module for Neorg.
    Summary: This module deals with handling everything related to the `:Neorg` command.
    ---
--]]

require("neorg.modules.base")
require("neorg.modules")
require("neorg.events")

local log = require("neorg.external.log")

local module = neorg.modules.create("core.neorgcmd")

module.examples = {
    ["Adding a Neorg command"] = function()
        -- In your module.setup(), make sure to require core.neorgcmd (requires = { "core.neorgcmd" })
        -- Afterwards in a function of your choice that gets called *after* core.neorgcmd gets intialized e.g. load():

        module.load = function()
            module.required["core.neorgcmd"].add_commands_from_table({
                -- The name of our command
                my_command = {
                    min_args = 1, -- Tells neorgcmd that we want at least one argument for this command
                    max_args = 1, -- Tells neorgcmd we want no more than one argument
                    args = 1, -- Setting this variable instead would be the equivalent of min_args = 1 and max_args = 1
                    -- This command is only avaiable within `.norg` files.
                    -- This can also be a function(bufnr, is_in_an_norg_file)
                    condition = "norg",

                    subcommands = { -- Defines subcommands
                        -- Repeat the definition cycle again
                        my_subcommand = {
                            args = 2, -- Force two arguments to be supplied
                            -- The identifying name of this command
                            -- Every "endpoint" must have a name associated with it
                            name = "my.command",

                            -- If your command takes in arguments versus
                            -- subcommands you can make a table of tables with
                            -- completion for those arguments here.
                            -- This table is optional.
                            complete = {
                                { "first_completion1", "first_completion2" },
                                { "second_completion1", "second_completion2" },
                            },

                            -- We do not define a subcommands table here because we don't have any more subcommands
                            -- Creating an empty subcommands table will cause errors so don't bother
                        },
                    },
                },
            })
        end

        -- Afterwards, you want to subscribe to the corresponding event:

        module.events.subscribed = {
            ["core.neorgcmd"] = {
                ["my.command"] = true, -- Has the same name as our "name" variable had in the "data" table
            },
        }

        -- There's also another way to define your own custom commands that's a lot more automated. Such automation can be achieved
        -- by putting your code in a special directory. That directory is in core.neorgcmd.commands. Creating your modules in this directory
        -- will allow users to easily enable you as a "command module" without much hassle.

        -- To enable a command in the commands/ directory, do this:

        require("neorg").setup({
            load = {
                ["core.neorgcmd"] = {
                    config = {
                        load = {
                            "some.neorgcmd", -- The name of a valid command
                        },
                    },
                },
            },
        })

        -- And that's it! You're good to go.
        -- Want to find out more? Read the wiki entry! https://github.com/nvim-neorg/neorg/wiki/Neorg-Command
    end,
}

module.load = function()
    -- Define the :Neorg command with autocompletion taking any number of arguments (-nargs=*)
    -- If the user passes no arguments or too few, we'll query them for the remainder using select_next_cmd_arg.
    vim.api.nvim_create_user_command("Neorg", module.private.command_callback, {
        nargs = "*",
        complete = module.private.generate_completions,
    })

    -- Loop through all the command modules we want to load and load them
    for _, command in ipairs(module.config.public.load) do
        -- If one of the command modules is "default" then load all the default modules
        if command == "default" then
            for _, default_command in ipairs(module.config.public.default) do
                module.public.add_commands_from_file(default_command)
            end
        end
    end
end

module.config.public = {
    load = {
        "default",
    },

    default = {
        "module.list",
        "module.load",
        "return",
    },
}

---@class core.neorgcmd
module.public = {
    -- The table containing all the functions. This can get a tad complex so I recommend you read the wiki entry
    neorg_commands = {},

    --- Recursively merges the contents of the module's config.public.funtions table with core.neorgcmd's module.config.public.neorg_commands table.
    ---@param module_name string #An absolute path to a loaded module with a module.config.public.neorg_commands table following a valid structure
    add_commands = function(module_name)
        local module_config = neorg.modules.get_module(module_name)

        if not module_config or not module_config.neorg_commands then
            return
        end

        module.public.neorg_commands =
            vim.tbl_deep_extend("force", module.public.neorg_commands, module_config.neorg_commands)
    end,

    --- Recursively merges the provided table with the module.config.public.neorg_commands table.
    ---@param functions table #A table that follows the module.config.public.neorg_commands structure
    add_commands_from_table = function(functions)
        module.public.neorg_commands = vim.tbl_deep_extend("force", module.public.neorg_commands, functions)
    end,

    --- Takes a relative path (e.g "list.modules") and loads it from the commands/ directory
    ---@param name string #The relative path of the module we want to load
    add_commands_from_file = function(name)
        -- Attempt to require the file
        local err, ret = pcall(require, "neorg.modules.core.neorgcmd.commands." .. name .. ".module")

        -- If we've failed bail out
        if not err then
            log.warn(
                "Could not load command",
                name,
                "for module core.neorgcmd - the corresponding module.lua file does not exist."
            )
            return
        end

        -- Load the module from table
        neorg.modules.load_module_from_table(ret)
    end,

    --- Rereads data from all modules and rebuild the list of available autocompletions and commands
    sync = function()
        -- Loop through every loaded module and set up all their commands
        for _, mod in pairs(neorg.modules.loaded_modules) do
            if mod.public.neorg_commands then
                module.public.add_commands_from_table(mod.public.neorg_commands)
            end
        end
    end,

    --- Defines a custom completion function to use for core.neorgcmd.
    ---@param callback #(function) - the same function format as you would receive by being called by :command -completion=customlist,v:lua.callback Neorg
    set_completion_callback = function(callback)
        module.private.generate_completions = callback
    end,
}

module.private = {
    --- Handles the calling of the appropriate function based on the command the user entered
    command_callback = function(data)
        local args = data.fargs

        local current_buf = vim.api.nvim_get_current_buf()
        local is_norg = vim.api.nvim_buf_get_option(current_buf, "filetype") == "norg"

        local function check_condition(condition)
            if condition == nil then
                return true
            end

            if condition == "norg" and not is_norg then
                return false
            end

            if type(condition) == "function" then
                return condition(current_buf, is_norg)
            end

            return condition
        end

        local ref = {
            subcommands = module.public.neorg_commands,
        }
        local argument_index = 0

        for i, cmd in ipairs(args) do
            if not ref.subcommands or vim.tbl_isempty(ref.subcommands) then
                break
            end

            ref = ref.subcommands[cmd]

            if not ref then
                log.error(
                    ("Error when executing `:Neorg %s` - such a command does not exist!"):format(
                        table.concat(vim.list_slice(args, 1, i), " ")
                    )
                )
                return
            elseif not check_condition(ref.condition) then
                log.error(
                    ("Error when executing `:Neorg %s` - the command is currently disabled. Some commands will only become available under certain conditions!"):format(
                        table.concat(vim.list_slice(args, 1, i), " ")
                    )
                )
                return
            end

            argument_index = i
        end

        local argument_count = (#args - argument_index)

        if ref.args then
            ref.min_args = ref.args
            ref.max_args = ref.args
        elseif ref.min_args and not ref.max_args then
            ref.max_args = math.huge
        else
            ref.min_args = ref.min_args or 0
            ref.max_args = ref.max_args or 0
        end

        if #args == 0 or argument_count < ref.min_args then
            local completions = module.private.generate_completions(_, table.concat({ "Neorg ", data.args, " " }))
            module.private.select_next_cmd_arg(data.args, completions)
            return
        elseif argument_count > ref.max_args then
            log.error(
                ("Error when executing `:Neorg %s` - too many arguments supplied! The command expects %s argument%s."):format(
                    data.args,
                    ref.max_args == 0 and "no" or ref.max_args,
                    ref.max_args == 1 and "" or "s"
                )
            )
            return
        end

        if not ref.name then
            log.error(
                ("Error when executing `:Neorg %s` - the ending command didn't have a `name` variable associated with it! This is an implementation error on the developer's side, so file a report to the author of the module."):format(
                    data.args
                )
            )
            return
        end

        if not module.events.defined[ref.name] then
            module.events.defined[ref.name] = neorg.events.define(module, ref.name)
        end

        neorg.events.broadcast_event(
            neorg.events.create(
                module,
                table.concat({ "core.neorgcmd.events.", ref.name }),
                vim.list_slice(args, argument_index + 1)
            )
        )
    end,

    --- This function returns all available commands to be used for the :Neorg command
    ---@param _ nil #Placeholder variable
    ---@param command string #Supplied by nvim itself; the full typed out command
    generate_completions = function(_, command)
        local current_buf = vim.api.nvim_get_current_buf()
        local is_norg = vim.api.nvim_buf_get_option(current_buf, "filetype") == "norg"

        local function check_condition(condition)
            if condition == nil then
                return true
            end

            if condition == "norg" and not is_norg then
                return false
            end

            if type(condition) == "function" then
                return condition(current_buf, is_norg)
            end

            return condition
        end

        command = command:gsub("^%s*", "")

        local splitcmd = vim.list_slice(
            vim.split(command, " ", {
                plain = true,
                trimempty = true,
            }),
            2
        )

        local ref = {
            subcommands = module.public.neorg_commands,
        }
        local last_valid_ref = ref
        local last_completion_level = 0

        for _, cmd in ipairs(splitcmd) do
            if not ref or not check_condition(ref.condition) then
                break
            end

            ref = ref.subcommands or {}
            ref = ref[cmd]

            if ref then
                last_valid_ref = ref
                last_completion_level = last_completion_level + 1
            end
        end

        if not last_valid_ref.subcommands and last_valid_ref.complete then
            if type(last_valid_ref.complete) == "function" then
                last_valid_ref.complete = last_valid_ref.complete(current_buf, is_norg)
            end

            if vim.endswith(command, " ") then
                local completions = last_valid_ref.complete[#splitcmd - last_completion_level + 1] or {}

                if type(completions) == "function" then
                    completions = completions(current_buf, is_norg) or {}
                end

                return completions
            else
                local completions = last_valid_ref.complete[#splitcmd - last_completion_level] or {}

                if type(completions) == "function" then
                    completions = completions(current_buf, is_norg) or {}
                end

                return vim.tbl_filter(function(key)
                    return key:find(splitcmd[#splitcmd])
                end, completions)
            end
        end

        -- TODO: Fix `:Neorg m <tab>` giving invalid completions
        local keys = ref and vim.tbl_keys(ref.subcommands or {})
            or (
                vim.tbl_filter(function(key)
                    return key:find(splitcmd[#splitcmd])
                end, vim.tbl_keys(last_valid_ref.subcommands or {}))
            )
        table.sort(keys)

        do
            local subcommands = (ref and ref.subcommands or last_valid_ref.subcommands) or {}

            return vim.tbl_filter(function(key)
                return check_condition(subcommands[key].condition)
            end, keys)
        end
    end,

    --- Queries the user to select next argument
    ---@param qargs table #A string of arguments previously supplied to the Neorg command
    ---@param choices table #all possible choices for the next argument
    select_next_cmd_arg = function(qargs, choices)
        local current = table.concat({ "Neorg ", qargs })

        local query

        if vim.tbl_isempty(choices) then
            query = function(...)
                vim.ui.input(...)
            end
        else
            query = function(...)
                vim.ui.select(choices, ...)
            end
        end

        query({
            prompt = current,
        }, function(choice)
            if choice ~= nil then
                vim.cmd(string.format("%s %s", current, choice))
            end
        end)
    end,
}

module.neorg_post_load = module.public.sync

return module
