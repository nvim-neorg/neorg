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
                definitions = { -- Used for completion
                    my_command = { -- Define a command called my_command
                        my_subcommand = {}, -- Define a subcommand called my_subcommand
                    },
                },
                data = { -- Metadata about our commands, should follow the same structure as the definitions table
                    my_command = {
                        min_args = 1, -- Tells neorgcmd that we want at least one argument for this command
                        max_args = 1, -- Tells neorgcmd we want no more than one argument
                        args = 1, -- Setting this variable instead would be the equivalent of min_args = 1 and max_args = 1

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
        -- Want to find out more? Read the wiki entry! https://github.com/vhyrro/neorg/wiki/Neorg-Command
    end,
}

--- This global function returns all available commands to be used for the :Neorg command
---@param _ nil #Placeholder variable
---@param command string #Supplied by nvim itself; the full typed out command
function _neorgcmd_generate_completions(_, command)
    -- If core.neorgcmd is not loaded do not provide completion
    if not neorg.modules.is_module_loaded("core.neorgcmd") then
        return { "Unable to provide completions: core.neorgcmd is not loaded." }
    end

    -- Trim any leading whitespace that may be present in the command
    command = command:gsub("^%s*", "")

    -- Split the command into several smaller ones for easy parsing
    local split_command = vim.split(command, " ")

    -- Create a reference to the definitions table
    local ref = module.public.neorg_commands.definitions

    -- If the split command contains only 2 values then don't bother with
    -- the code below, just return all the available completions and exit
    if #split_command == 2 then
        return vim.tbl_filter(function(key)
            return key ~= "__any__" and key:find(split_command[#split_command])
        end, vim.tbl_keys(ref))
    end

    -- Splice the command to omit the beginning :Neorg bit
    local sliced_split_command = vim.list_slice(split_command, 2)

    -- If the last element is not an empty string then add it, it serves as a terminator for neorgcmd's completion
    if sliced_split_command[#sliced_split_command] ~= "" then
        sliced_split_command[#sliced_split_command] = ""
    end

    -- This is where the magic begins - recursive reference assignment
    -- What we do here is we recursively traverse down the module.public.neorg_commands.definitions
    -- table and provide autocompletion based on how many commands we have typed into the :Neorg command.
    -- If we e.g. type ":Neorg list " and then press Tab we want to traverse once down the table
    -- and return all the contents at the first recursion level of that table.
    for _, cmd in ipairs(sliced_split_command) do
        if ref[cmd] then
            ref = ref[cmd]
        elseif cmd:len() > 0 and ref.__any__ then
            ref = ref.__any__
        else
            break
        end
    end

    -- Return everything from ref that is a potential match
    return vim.tbl_filter(function(key)
        return key ~= "__any__" and key:find(split_command[#split_command])
    end, vim.tbl_keys(ref))
end

--- Queries the user to select next argument
---@param args table #previous arguments of the command Neorg
---@param choices table #all possible choices for the next argument
local _select_next_cmd_arg = function(args, choices)
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
end

module.load = function()
    -- Define the :Neorg command with autocompletion taking any number of arguments (-nargs=*)
    -- If the user passes no arguments or too few, we'll query them for the remainder, using _select_next_cmd_arg.
    vim.cmd(
        [[ command! -nargs=* -complete=customlist,v:lua._neorgcmd_generate_completions Neorg :lua require('neorg.modules.core.neorgcmd.module').public.function_callback(<f-args>) ]]
    )

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

        module.public.neorg_commands = vim.tbl_deep_extend(
            "force",
            module.public.neorg_commands,
            module_config.neorg_commands
        )
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

    --- Handles the calling of the appropriate function based on the command the user entered
    -- @Param  ... (varargs) - the contents of <f-args> provided by nvim itself
    function_callback = function(...)
        -- Unpack the varargs into a table
        local args = { ... }

        --[[
		--	Ok, this is where things get messy. Read the comments from the _neorgcmd_generate_completions()
		--	function to get a decent grasp of the code below. Before you ask, yes, all these variables
		--	here are necessary in order for the function to work. Time to explain them one by one:
		--		ref_definitions - a reference to the module.config.public.neorg_commands.definitions table, recursive reference assignment is done here.
		--			It's used to track where we are recursively in the table. It's also used to build a valid event string and to test whether the supplied
		--			commands and subcommands actually exist.
		--		ref_data - a reference to the module.config.public.neorg_commands.data table. It's used to recursively enter the "subcommands" tables and
		--			tell the for loop below when to bail out and stop parsing further.
		--		ref_data_one_above - the same as ref_data, except used for a different purpose. As the name suggests, this variable is a reference to one level above ref_data.
		--			You still with me? This variable is used to read the metadata present in the neorg_commands.data table, it doesn't instantly enter the "subcommands" table like ref_data
		--			does.
		--		event_name - the current event string. Tracks the tail of the command we're executing.
		--		current_depth - the current recursion depth. Used to track what is a command/subcommand and what are arguments.
		--]]
        local ref_definitions = module.public.neorg_commands.definitions
        local ref_data = module.public.neorg_commands.data
        local ref_data_one_above = module.public.neorg_commands.data
        local event_name = ""
        local current_depth = 0

        -- For every argument we have received do
        for _, cmd in ipairs(args) do
            -- If we can recursively enter the definitions table then
            if ref_definitions[cmd] then
                -- If we can recursively enter the data table then
                if ref_data[cmd] then
                    -- Assign ref_data_one_above to the correct value
                    ref_data_one_above = ref_data[cmd]

                    -- Recursively assign the ref_definitions reference (equivalent of entering the table)
                    ref_definitions = ref_definitions[cmd]

                    -- Set the event_name string
                    event_name = ref_data_one_above.name

                    -- Increase the current recursion depth
                    current_depth = current_depth + 1

                    -- If we have another subcommands table to enter then enter it, otherwise there's no more recursion to do and we can bail out
                    if ref_data[cmd].subcommands then
                        ref_data = ref_data[cmd].subcommands
                    else
                        break
                    end
                else -- If we can't enter the data table then that means it's inconsistent with the definitions table
                    log.error(
                        "Unable to execute command :Neorg",
                        ...,
                        cmd,
                        "- the command exists but doesn't hold any valid metadata. Metadata is required for neorg to parse the command correctly, please consult the neorg wiki if you're confused."
                    )
                    return
                end
            else -- If we can't enter the definitions table further then that means the command we entered does not exist
                log.error("Unable to execute command :Neorg", ..., cmd, "- such a command does not exist.")
                return
            end
        end

        -- PARSE COMMAND METADATA (read wiki for metadata info)

        -- If we have not specified the min_args value default to 0
        ref_data_one_above.min_args = ref_data_one_above.min_args or 0

        -- If we've defined an args variable then set both the min_args and max_args to that value
        if ref_data_one_above.args then
            ref_data_one_above.min_args = ref_data_one_above.args
            ref_data_one_above.max_args = ref_data_one_above.args
        end

        -- If our recursion depth is smaller than the minimum argument count then that means the user has not supplied enough arguments
        -- We'll therefore query the user for the remainder
        if #args == 0 or #args - current_depth < ref_data_one_above.min_args then
            -- When an insufficient amount of arguments are provided Neorg will query for the next mandatory
            -- argument - this may not be done with the `ref_definitions` table however, as `ref_definitions`
            -- performs a recursion on the data of each keybind versus the completions of each keybind. This means
            -- that keybinds with many arguments wouldn't be registered and would instead cause this function to
            -- loop. The only solution is to query completions for the next item here.
            local completions = _neorgcmd_generate_completions(_, string.format("Neorg %s ", table.concat(args, " ")))
            _select_next_cmd_arg(args, completions)
            return
        end

        -- If our event name is nil then that means the command did not have a `name` field defined
        if not event_name then
            log.error("Unable to execute neorg command. The command does not have a 'name' field to identify it.")
            return
        end

        -- If our recursion depth is larger than the maximum argument count then that means we have supplied too many arguments
        if ref_data_one_above.max_args and #args - current_depth > ref_data_one_above.max_args then
            if ref_data_one_above.max_args == 0 then
                log.error(
                    "Unable to execute neorg command under name",
                    event_name,
                    "- exceeded maximum argument count. The command does not take any arguments."
                )
            else
                log.error(
                    "Unable to execute neorg command under name",
                    event_name,
                    "- exceeded maximum argument count. The command does not allow more than",
                    ref_data_one_above.max_args,
                    "arguments."
                )
            end

            return
        end

        -- If not already defined define our event
        if not module.events.defined[event_name] then
            module.events.defined[event_name] = neorg.events.define(module, event_name)
        end

        -- Broadcast the event with all the correct data and the arguments passed to our command as the contents
        neorg.events.broadcast_event(
            neorg.events.create(
                module,
                "core.neorgcmd.events." .. event_name,
                vim.list_slice(args, #args - (#args - current_depth) + 1)
            )
        )
    end,

    --- Defines a custom completion function to use for core.neorgcmd.
    ---@param callback #(function) - the same function format as you would receive by being called by :command -completion=customlist,v:lua.callback Neorg
    set_completion_callback = function(callback)
        _neorgcmd_generate_completions = callback
    end,
}

module.neorg_post_load = module.public.sync

return module
