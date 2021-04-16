
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
function neorg.modules.load_module_from_table(module)

	log.info('Loading module with name', module.name)

	-- If our module is already loaded don't try loading it again
	if neorg.modules.loaded_modules[module.name] then
		log.warn('Module', module.name, 'already loaded. Omitting...')
		return false
	end

	-- module.setup() will soon return more than just a success variable, eventually we'd like modules to expose metadata about themselves too
	local loaded_module = module.setup()

	-- We do not expect module.setup() to ever return nil, that's why this check is in place
	if not loaded_module then
		log.error('Module', module.name, 'does not handle module loading correctly; module.load() returned nil. Omitting...')
		return false
	end

	-- A part of the table returned by module.setup() tells us whether or not the module initialization was successful
	if loaded_module.success == false then
		log.info('Module', module.name, 'did not load.')
		return false
	end

	if loaded_module.requires and vim.tbl_count(loaded_module.requires) > 0 then

		log.info('Module', module.name, 'has dependencies. Loading dependencies first...')

		for _, required_module in pairs(loaded_module.requires) do

			log.trace('Loading submodule', required_module)

			if not neorg.modules.is_module_loaded(required_module) then
				if not neorg.modules.load_module(required_module) then
					log.error(("Unable to load module %s, required dependency %s did not load successfully"):format(module.name, required_module))
					return false
				end
			end

			module.required[required_module] = neorg.modules.loaded_modules[required_module].public

		end

	end

	if module.config.keymaps and vim.tbl_count(module.config.keymaps) > 0 then

		log.info('Module', module.name, 'has keymaps. Binding...')

		for keyname, keymap in pairs(module.config.keymaps) do
			log.trace('Loading keymap', keyname)
			vim.api.nvim_set_keymap(keymap.mode, keyname, ':lua require(\'neorg.modules.' .. module.name .. '.module\').on_keymap(\'' .. keymap.name .. '\')<CR>', keymap.options or {})
		end

		log.info('Loaded all keymaps for module', module.name)

	end

	log.info('Successfully loaded module', module.name)

	-- Add the module into the list of loaded modules
	neorg.modules.loaded_modules[module.name] = module

	-- Keep track of the number of loaded modules
	neorg.modules.loaded_module_count = neorg.modules.loaded_module_count + 1

	-- Call the load function
	module.load()

	return true

end

function neorg.modules.load_module(module_name, shortened_git_address)

	-- local git_sites = { 'github.com', 'gitlab.com', 'bitbucket.org' }

	local exists, module = pcall(require, 'neorg.modules.' .. module_name .. '.module')

	if not exists then

		if shortened_git_address then
			-- If module isn't found, grab it from the internet here
			return false
		end

		return false
	end

	if not module then
		return false
	end

	local config = neorg.configuration.user_configuration

	if config then
		module.config.public = vim.tbl_deep_extend('force', module.config.public, config.module_configs[module.name] or {})
		if config.module_keymaps then
			module.config.keymaps = vim.tbl_deep_extend('force', module.config.keymaps, config.module_keymaps[module.name] or {})
		end
	end

	return neorg.modules.load_module_from_table(module)

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
-- @Description Retrieves the public API exposed by the module
-- @Param  module_name (string) - the name of the module to retrieve
function neorg.modules.get_module(module_name)

	if not neorg.modules.is_module_loaded(module_name) then
		log.info("Attempt to get module with name", module_name, "failed.")
		return nil
	end

	return neorg.modules.loaded_modules[module_name].public
end

-- @Summary Check whether a module is loaded
-- @Description Returns true if module with name module_name is loaded, false otherwise
-- @Param  module_name (string) - the name of an arbitrary module
function neorg.modules.is_module_loaded(module_name)
	return neorg.modules.loaded_modules[module_name] ~= nil
end
