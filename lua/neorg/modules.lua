--[[
--	NEORG MODULE MANAGER
--	This file is responsible for loading, unloading, calling and managing modules
--	Modules are internal mini-programs that execute on certain events, they build the foundation of neorg itself.
--]]

local log = require('neorg.external.log')

require('neorg.modules.base')

--[[
--	The reason we do not just call this variable neorg.modules.loaded_modules.count is because
--	someone could make a module called 'count' and override the variable, causing bugs.
--]]
neorg.modules.loaded_module_count = 0

neorg.modules.loaded_modules = {}

-- @Summary Load and enables a module
-- @Description Loads a specified module. If the module subscribes to any events then they will be activated too.
-- @Param  module (table) - the actual module to load
function neorg.modules.load_module(module)

	log.info('Loading module with name', module.name)

	-- If our module is already loaded don't try loading it again
	if neorg.modules.loaded_modules[module.name] then
		log.warn('Module', module.name, 'already loaded. Omitting...')
		return false
	end

	-- module.load() returns a table containing metadata about itself
	local loaded_module = module.load(neorg.modules.loaded_modules, neorg.modules.loaded_module_count)

	-- We do not expect module.load() to ever return nil, that's why this check is in place
	if not loaded_module then
		log.warn('Module', module.name, 'does not handle module loading correctly; module.load() returned nil. Omitting...')
		return false
	end

	-- A part of the table returned by module.load() tells us whether or not the module initialization was successful
	if loaded_module.loaded == false then
		log.info('Module', module.name, 'did not load.')
		return false
	end

	log.trace('Subscribing to events for module', module.name)

	-- Import the event manager
	local events = require('neorg.events')

	-- If the module has chosen to subscribe to any events, make sure to actually subscribe to them
	if loaded_module.subscribed_events then

		log.trace('Module', module.name, 'has events bound to it, subscribing to all provided...')

		for _, event_type in pairs(loaded_module.subscribed_events) do
			log.trace('Binding event', event_type, 'to module', module.name)
			events.subscribe(module.name, event_type)
		end
	else
		log.trace('Module', module.name, 'is not subscribed to any events.')
	end

	log.info('Successfully loaded module', module.name)

	-- Add the module into the list of loaded modules
	neorg.modules.loaded_modules[module.name] = module

	-- Keep track of the number of loaded modules
	neorg.modules.loaded_module_count = neorg.modules.loaded_module_count + 1

	return true

end

-- @Summary Unloads a module by name
-- @Description Removes all hooks, all event subscriptions and unloads the module from memory
-- @Param module_name (string) - the name of the module to unload
function neorg.modules.unload_module(module_name)

	local module = neorg.modules.loaded_module[module_name]

	if not module then
		log.info("Unable to unload module", module_name, "- module is not currently loaded.")
		return false
	end

	module.unload()

	neorg.modules.loaded_module[module_name] = nil

	neorg.modules.loaded_module_count = neorg.modules.loaded_module_count - 1

	return true
end

-- @Summary Gets a module by name
-- @Description Retrieves a module from the loaded_modules table, returns nil if no module is found
-- @Param  module_name (string) - the name of the module to retrieve
function neorg.modules.get_module_by_name(module_name)
	return neorg.modules.loaded_modules[module_name]
end

-- @Summary Check whether a module is loaded
-- @Description Returns true if module with name module_name is loaded, false otherwise
-- @Param  module_name (string) - the name of an arbitrary module
function neorg.modules.is_module_loaded(module_name)
	return neorg.modules.loaded_modules[module_name] ~= nil
end
