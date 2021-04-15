--[[
--	BASE FILE FOR MODULES
--	This file contains the base module implementation
--]]

neorg.modules = {}

neorg.modules.module_base = {

	-- Invoked whenever the module is loaded
	load = function()
		return { success = true, requires = {} }
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
	public = {

		version = '0.0.1' -- A good practice is to expose version information

	},

	-- Event data regarding the current module
	events = {
		subscribed = { -- The events that the module is subscribed to

			--[[
				EXAMPLE DEFINITION:
				[ 'core.test' ] = { -- The name of the module that has events bound to it
					[ 'test_event' ] = true,
					[ 'other_event' ] = true
				}
			--]]

		},
		defined = { -- The events that the module itself has defined

			--[[
				EXAMPLE DEFINITION:
				['my_event'] = { event_data }
			--]]

		}
	},

}

-- @Summary Creates a new module
-- @Description Returns a module that derives from neorg.modules.module_base, exposing all the necessary function and variables
-- @Param  name (string) - the name of the new module. Make sure this is unique. The recommended naming convention is category.module_name or category.subcategory.module_name
function neorg.modules.create(name)
	local new_module = {}
	setmetatable(new_module, { __index = neorg.modules.module_base })

	if name then
		new_module.name = name
	end

	return new_module
end
