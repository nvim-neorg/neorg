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
                -- The name of our subcommand
                my_command = {
                    min_args = 1, -- Tells neorgcmd that we want at least one argument for this command
                    max_args = 1, -- Tells neorgcmd we want no more than one argument
                    args = 1, -- Setting this variable instead would be the equivalent of min_args = 1 and max_args = 1
                    condition = "norg", -- This command is only avaiable within `.norg` files

                    subcommands = { -- Defines subcommands
                        -- Repeat the definition cycle again
                        my_subcommand = {
                            args = 0, -- We don't want any arguments
                            name = "my.command", -- The identifying name of this command

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
    end,

    --- This function returns all available commands to be used for the :Neorg command
    ---@param _ nil #Placeholder variable
    ---@param command string #Supplied by nvim itself; the full typed out command
    generate_completions = function(_, command)
        local current_buf = vim.api.nvim_get_current_buf()
        local is_norg = vim.api.nvim_buf_get_option(current_buf, "filetype") == "norg"

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

        for _, cmd in ipairs(splitcmd) do
            if not ref then
                break
            end

            ref = ref.subcommands or {}
            ref = ref[cmd]

            if ref then
                last_valid_ref = ref
            end
        end

        -- TODO: Fix `:Neorg m <tab>` giving invalid completions`
        local keys = ref and vim.tbl_keys(ref.subcommands or {})
            or (
                vim.tbl_filter(function(key)
                    return key:find(splitcmd[#splitcmd])
                end, vim.tbl_keys(last_valid_ref.subcommands or {}))
            )
        table.sort(keys)

        return keys
    end,

    --- Queries the user to select next argument
    ---@param args table #previous arguments of the command Neorg
    ---@param choices table #all possible choices for the next argument
    select_next_cmd_arg = function(args, choices)
        local current = string.format("Neorg %s", table.concat(args, " "))

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
