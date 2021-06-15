--[[
	MODE MANAGER FOR NEORG
	Modes are a way of isolating different parts of neorg based on the current mode. For example, a "header-jump" mode may exist which
	will rebind hjkl to move between headers instead of line-by-line.

USAGE:
	To add a mode to core.mode, use the public add_mode("my-mode-name").
	To set the current mode, use the public set_mode("my-mode-name").
	To retrieve the current mode name, use get_mode().
	To retrieve the *previous* mode name, use get_previous_mode().
	To retrieve *all* modes, use get_modes()

	If core.neorgcmd is loaded, core.mode.public.add_mode() also updates the autocompletion for the :Neorg set-mode command,
	which can be used by the user to switch modes.

EVENTS:
	core.mode.events.mode_created - invoked whenever a new mode is created.
		- event.content -> a table containing `current`, which contains the current mode we're in and `new`, which contains the name of the newly created mode.
	core.mode.events.mode_set - invoked whenever a mode is set.
		- event.content -> a table containing `current`, which contains the current mode we're in and `new`, which contains the name of the mode we will be switching to.

REQUIRES: core.mode does not require any modules to operate - it is standalone

--]]

require('neorg.modules.base')
require('neorg.events')

local module = neorg.modules.create("core.mode")

local log = require('neorg.external.log')

module.config.public = {

	-- As the name suggests, stores the current and previous mode
	current_mode = "norg",
	previous_mode = "norg",

}

module.private = {
	-- All the currently defined modes
	modes = {
		"norg"
	},
}

module.load = function()
	-- Broadcast the initial mode_set event whenever we enter Neorg for the first time
	neorg.events.broadcast_event(neorg.events.create(module, "core.mode.events.mode_set", { current = "", new = "norg" }))
end

module.public = {

	-- Define command for :Neorg
	neorg_commands = {
		definitions = {
			["set-mode"] = {
				norg = {}
			}
		},

		data = {
			["set-mode"] = {
				args = 1,
				name = "set-mode"
			}
		}
	},

	-- @Summary Adds a new mode to the list of available modes
	-- @Description This function lets the core.mode module know that a new mode should be added. This will be used in autocompletion for the :Neorg command
	-- @Param  mode_name (string) - the name of the mode to add
	add_mode = function(mode_name)

		-- If the mode is equal to all then error out - that mode name is reserved
		if mode_name == "all" then
			log.error("Unable to add mode 'all' - that name is reserved.")
			return
		end

		-- Add the new mode to the list of known modes
		table.insert(module.private.modes, mode_name)

		-- Broadcast the mode_created event
		neorg.events.broadcast_event(neorg.events.create(module, "core.mode.events.mode_created", { current = module.config.public.current_mode, new = mode_name }))

		-- Define the autocompletion tables and make them include the current mode
		module.public.neorg_commands.definitions["set-mode"][mode_name] = {}

		-- If core.neorgcmd is loaded then update all autocompletions
		local neorgcmd = neorg.modules.get_module("core.neorgcmd")

		if neorgcmd then
			neorgcmd.sync()
		end
	end,

	-- @Summary Sets the current neorg mode
	-- @Description Broadcasts to all subscribed modules that the mode has been changed
	-- @Param  mode_name (string) - the name of the mode to switch to
	set_mode = function(mode_name)
		-- If the mode name is the same as it used to be then don't bother
		if module.config.public.current_mode == mode_name then return end

		-- If the mode is equal to "all" then error out - that mode name is reserved
		if mode_name == "all" then
			log.error("Unable to set mode to 'all' - that name is reserved.")
			return
		end

		-- Set the previous mode to the current one, then set the current mode to the new mode
		module.config.public.previous_mode = module.config.public.current_mode
		module.config.public.current_mode = mode_name

		-- Broadcast the mode_set event to all subscribed modules
		neorg.events.broadcast_event(neorg.events.create(module, "core.mode.events.mode_set", { current = module.config.public.previous_mode, new = mode_name }))
	end,

	-- @Summary Gets the current mode
	get_mode = function() return module.config.public.current_mode end,

	-- @Summary Gets the previous mode
	-- @Description Retrieves the mode that was set before the current one
	get_previous_mode = function() return module.config.public.previous_mode end,

	get_modes = function() return module.private.modes end,

	version = "0.0.9"
}

module.on_event = function(event)
	-- Retrieve the :Neorg set-mode command and set the mode accordingly
	if event.type == "core.neorgcmd.events.set-mode" then
		module.public.set_mode(event.content[1])
	end
end

module.events.defined = {
	mode_created = neorg.events.define(module, "mode_created"), -- Broadcast when a mode is created
	mode_set = neorg.events.define(module, "mode_set"), -- Broadcast when a mode changes
}

module.events.subscribed = {
	["core.neorgcmd"] = {
		["set-mode"] = true
	}
}

return module
