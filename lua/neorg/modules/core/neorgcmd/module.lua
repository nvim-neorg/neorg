--[[
	NEORGCMD MODULE FOR NEORG
	This module deals with handling everything related to the :Neorg command.
	Things like completion and dynamic function calling are what this module is all about.

USAGE:

	In your module.setup(), make sure to require core.neorgcmd (requires = { "core.neorgcmd" })
	Afterwards in a function of your choice that gets called *after* core.neorgcmd gets intialized e.g. load():

	module.load = function()
		module.required["core.neorgcmd"].add_commands({
			definitions = { -- Used for completion
				my_command = { -- Define a command called my_command
					my_subcommand = {} -- Define a subcommand called my_subcommand
				}
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

							-- We do not define a subcommands table here because we don't have any more subcommands
							-- Creating an empty subcommands table will cause errors so don't bother
						}
					}
				}
			}
		})
	end

	Afterwards, you want to subscribe to the corresponding event:

	module.events.subscribed = {
		["core.neorgcmd"] = {
			["my_command.my_subcommand"] = true -- Events come in a fullstop-seperated format
		}
	}

WIP:
	There's also another way to define your own custom commands that's a lot more automated. Such automation can be achieved
	by putting your code in a special directory. Documentation will be added as features become available.

TODO: Add links to wiki here too!

--]]

require('neorg.modules.base')
require('neorg.modules')
require('neorg.events')

local log = require('neorg.external.log')

local module = neorg.modules.create("core.neorgcmd")

-- @Summary Generate autocompletions for the :Neorg command
-- @Description This global function returns all available commands to be used for the :Neorg command
-- @Param  _ (nil) - placeholder variable
-- @Param  command (string) - supplied by nvim itself; the full typed out command
function _neorgcmd_generate_completions(_, command)

	-- If core.neorgcmd is not loaded do not provide completion
	if not neorg.modules.is_module_loaded("core.neorgcmd") then
		return { "Unable to provide completions: core.neorgcmd is not loaded." }
	end

	-- Since this is a global function we need to retrieve the neorgcmd module
	local neorgcmd_module = require('neorg.modules.core.neorgcmd.module')

	-- Split the command into several smaller ones for easy parsing
	local split_command = vim.split(command, " ")

	-- Create a reference to the definitions table
	local ref = neorgcmd_module.config.public.functions.definitions

	-- If the split command contains only 2 values then don't bother with
	-- the code below, just return all the available completions and exit
	if #split_command == 2 then
		return vim.tbl_keys(ref)
	end

	-- This is where the magic begins - recursive reference assignment
	-- What we do here is we recursively traverse down the module.config.public.functions.definitions
	-- table and provide autocompletion based on how many commands we have typed into the :Neorg command.
	-- If we e.g. type ":Neorg list " and then press Tab we want to traverse once down the table
	-- and return all the contents at the first recursion level of that table.
	for _, cmd in ipairs(vim.list_slice(split_command, 2)) do
		if ref[cmd] then ref = ref[cmd] else break end
	end

	-- Return everything from ref
	return vim.tbl_keys(ref)
end

module.load = function()
	-- Define the :Neorg command with autocompletion and a requirement of at least one argument (-nargs=+)
	vim.cmd [[ command! -nargs=+ -complete=customlist,v:lua._neorgcmd_generate_completions Neorg :lua require('neorg.modules.core.neorgcmd.module').public.function_callback(<f-args>) ]]
end

module.config.public = {

	-- The table containing all the functions. This can get a tad complex so I recommend you read the wiki entry
	functions = {
		definitions = {
			list = {
				modules = {}
			}
		},
		data = {
			list = {
				args = 1,

				subcommands = {

					modules = {
						args = 0
					}

				}
			}
		}
	}

}

module.public = {

	-- @Summary Adds custom commands for core.neorgcmd to use
	-- @Description Recursively merges the provided table with the module.config.public.functions table.
	-- @Param  subcommands (table) - a table that follows the same structure as module.config.public.functions
	add_commands = function(commands)
		module.config.public.functions = vim.tbl_deep_extend("force", module.config.public.functions, commands)
	end,

	-- @Summary The callback function whenever the :Neorg command is executed
	-- @Description Handles the calling of the appropriate function based on the command the user entered
	-- @Param  ... (varargs) - the contents of <f-args> provided by nvim itself
	function_callback = function(...)

		-- Unpack the varargs into a table
		local args = { ... }

		--[[
		--	Ok, this is where things get messy. Read the comments from the _neorgcmd_generate_completions()
		--	function to get a decent grasp of the code below. Before you ask, yes, all these variables
		--	here are necessary in order for the function to work. Time to explain them one by one:
		--		ref_definitions - a reference to the module.config.public.functions.definitions table, recursive reference assignment is done here.
		--			It's used to track where we are recursively in the table. It's also used to build a valid event string and to test whether the supplied
		--			commands and subcommands actually exist.
		--		ref_data - a reference to the module.config.public.functions.data table. It's used to recursively enter the "subcommands" tables and
		--			tell the for loop below when to bail out and stop parsing further.
		--		ref_data_one_above - the same as ref_data, except used for a different purpose. As the name suggests, this variable is a reference to one level above ref_data.
		--			You still with me? This variable is used to read the metadata present in the functions.data table, it doesn't instantly enter the "subcommands" table like ref_data
		--			does.
		--		event_name - the current event string. Values are appended to this string as we recursively enter each table. It allows us to build a valid event string.
		--		current_depth - the current recursion depth. Used to track what is a command/subcommand and what are arguments.
		--]]
		local ref_definitions = module.config.public.functions.definitions
		local ref_data = module.config.public.functions.data
		local ref_data_one_above = module.config.public.functions.data
		local event_name = "core.neorgcmd.events"
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

					-- Build the event_name string further
					event_name = event_name .. "." .. cmd

					-- Increase the current recursion depth
					current_depth = current_depth + 1

					-- If we have another subcommands table to enter then enter it, otherwise there's no more recursion to do and we can bail out
					if ref_data[cmd].subcommands then
						ref_data = ref_data[cmd].subcommands
					else
						break
					end

				else -- If we can't enter the data table then that means it's inconsistent with the definitions table
					log.error("Unable to execute neorg command under the name", event_name .. "." .. cmd, "- the command exists but doesn't hold any valid metadata. Metadata is required for neorg to parse the command correctly, please consult the neorg wiki if you're confused.")
					return
				end
			else -- If we can't enter the definitions table further then that means the command we entered does not exist
				log.error("Unable to execute neorg command under the name", event_name .. "." .. cmd, "- such a command does not exist.")
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

		-- If our recursion depth is smaller than the minimum argument count then that means we have not supplied enough arguments
		if #args - current_depth < ref_data_one_above.min_args then
			log.error("Unable to execute neorg command under name", event_name, "- minimum argument count not satisfied. The command requires at least", ref_data_one_above.min_args, "arguments.")
			return
		end

		-- If our recursion depth is larger than the maximum argument count then that means we have supplied too many arguments
		if ref_data_one_above.max_args and #args - current_depth > ref_data_one_above.max_args then
			if ref_data_one_above.max_args == 0 then
				log.error("Unable to execute neorg command under name", event_name, "- exceeded maximum argument count. The command does not take any arguments.")
			else
				log.error("Unable to execute neorg command under name", event_name, "- exceeded maximum argument count. The command does not allow more than", ref_data_one_above.max_args, "arguments.")
			end

			return
		end

		-- Create a relative path from the generated absolute one
		local relative_path = event_name:sub(("core.neorgcmd.events."):len() + 1)

		-- Define the event so we can broadcast it
		module.events.defined[relative_path] = neorg.events.define(module, relative_path)

		-- Broadcast the event with all the correct data and the arguments passed to our command as the contents
		neorg.events.broadcast_event(module, neorg.events.create(module, event_name, vim.list_slice(args, #args - (#args - current_depth) + 1)))
	end,

	-- @Summary Overwrites the completion callback function
	-- @Description Defines a custom completion function to use for core.neorgcmd.
	-- @Param  callback (function) - the same function format as you would receive by being called by :command -completion=customlist,v:lua.callback Neorg
	set_completion_callback = function(callback)
		_neorgcmd_generate_completions = callback
	end

}

return module
