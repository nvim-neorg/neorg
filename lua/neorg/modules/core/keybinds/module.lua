
require('neorg.modules.base')

local module = neorg.modules.create("core.keybinds")

local log = require('neorg.external.log')

module.setup = function()
	return { success = true, requires = { "core.neorgcmd", "core.mode" } }
end

module.public = {

	-- Define neorgcmd autocompletions and commands
	neorg_commands = {
		definitions = {
			keybind = {}
		},
		data = {
			keybind = {
				args = 2,
				name = "core.keybinds.trigger"
			}
		},
	},

	keybinds = {},

	-- @Summary Registers a new keybind
	-- @Description Adds a new keybind to the database of known keybinds
	-- @Param  module_name (string) - the name of the module that owns the keybind. Make sure it's an absolute path.
	-- @Param  name (string) - the name of the keybind. The module_name will be prepended to this string to form a unique name.
	register_keybind = function(module_name, name)
		-- Create the full keybind name
		local keybind_name = module_name .. "." .. name

		-- If that keybind is not defined yet then define it
		if not module.events.defined[keybind_name] then
			module.events.defined[keybind_name] = neorg.events.define(module, keybind_name)

			-- Define autocompletion for core.neorgcmd
			module.public.keybinds[keybind_name] = {}
		end

		-- Update core.neorgcmd's internal tables
		module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
	end,

	-- @Summary Registers a batch of keybinds
	-- @Description Like register_keybind(), except registers a batch of them
	-- @Param  module_name (string) - the name of the module that owns the keybind. Make sure it's an absolute path.
	-- @Param  names (list of strings) - a list of strings detailing names of the keybinds. The module_name will be prepended to each one to form a unique name.
	register_keybinds = function(module_name, names)

		-- Loop through each name from the names argument
		for _, name in ipairs(names) do
			-- Create the full keybind name
			local keybind_name = module_name .. "." .. name

			-- If that keybind is not defined yet then define it
			if not module.events.defined[keybind_name] then
				module.events.defined[keybind_name] = neorg.events.define(module, keybind_name)

				-- Define autocompletion for core.neorgcmd
				module.public.keybinds[keybind_name] = {}
			end
		end

		-- Update core.neorgcmd's internal tables
		module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
	end,

	-- @Summary Synchronizes all autocompletions
	-- @Description Updates the list of known modes and keybinds for easy autocompletion. Invoked automatically during neorg_post_load().
	sync = function()
		-- Reset all the autocompletions
		module.public.neorg_commands.definitions.keybind = {}

		-- Grab all the modes
		local modes = module.required["core.mode"].get_modes()

		-- Set autocompletion for the "all" mode
		module.public.neorg_commands.definitions.keybind.all = module.public.keybinds

		-- Convert the list of modes into completion entries for core.neorgcmd
		for _, mode in ipairs(modes) do
			module.public.neorg_commands.definitions.keybind[mode] = module.public.keybinds
		end

		-- Update core.neorgcmd's internal tables
		module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
	end

}

module.neorg_post_load = module.public.sync

module.on_event = function(event)
	if event.type == "core.neorgcmd.events.core.keybinds.trigger" then
		-- Query the current mode and the expected mode (the one passed in by the user)
		local expected_mode = event.content[1]
		local current_mode = module.required["core.mode"].get_mode()

		-- If the modes don't match then don't execute the keybind
		if expected_mode ~= current_mode and expected_mode ~= "all" then
			return
		end

		-- Get the event path to the keybind
		local keybind_event_path = event.content[2]

		-- If it is defined then broadcast the event
		if module.events.defined[keybind_event_path] then
			neorg.events.broadcast_event(module, neorg.events.create(module, "core.keybinds.events." .. keybind_event_path))
		else -- Otherwise throw an error
			log.error("Unable to trigger keybind", keybind_event_path, "- the keybind does not exist")
		end
	end
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		["core.keybinds.trigger"] = true
	}
}

return module
