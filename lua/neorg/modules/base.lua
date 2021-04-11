--[[
--	BASE FILE FOR MODULES
--	This file contains the base module implementation
--]]

neorg.modules = {}

neorg.modules.module_base = {

	-- Invoked whenever the module is loaded
	load = function(loaded_modules, loaded_module_count)
		return { loaded = true, subscribed_events = nil }
	end,

	-- Invoked whenever the module is unloaded
	unload = function()
	end,

	-- Invoked whenever an event that the module has subscribed to triggers
	on_event = function(event)
	end,

	-- The name of the module, note that modules beginning with core are neorg's inbuilt modules
	name = 'core.default',

	-- Every module can expose any set of information it sees fit through the public field
	-- All functions and variables declared in this table will be visible to any other module loaded
	public = {}

}

-- @Summary Creates a new module
-- @Description Returns a module that derives from neorg.modules.module_base, exposing all the necessary function and variables
-- @Param  name (string) - the name of the new module. Make sure this is unique. The recommended naming convention is username.module_name, but if your module name is unique enough the just a regular module name can suffice
function neorg.modules.create(name)
	local new_module = {}
	setmetatable(new_module, { __index = neorg.modules.module_base })

	if name then
		new_module.name = name
	end

	return new_module
end
