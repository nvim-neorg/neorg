--[[
--	ROOT NEORG FILE
--	This file is the begininng of the entire plugin. It's here that everything fires up and starts pumping.
--]]

-- Require the most important modules
require('neorg.callbacks')
require('neorg.events')
require('neorg.modules')

local configuration = require('neorg.config')

-- @Summary Sets up neorg
-- @Description This function takes in a user configuration, parses it, initializes everything and launches neorg if inside a .norg or .org file
-- @Param  config (table) - a table that reflects the structure of configuration.user_configuration
function neorg.setup(config)
	configuration.user_configuration = config or {}

	-- Create a new global instance of the neorg logger
	require('neorg.external.log').new(configuration.user_configuration.logger or log.get_default_config(), true)

	-- If the community module path has not been set then set it to its default location
	if not config.community_module_path then
		configuration.user_configuration.community_module_path = vim.fn.stdpath("cache") .. "/neorg_community_modules"
	end

	-- If we are launching a .norg or .org file, fire up the modules!
	local ext = vim.fn.expand("%:e")

	if ext == "org" or ext == "norg" then 
		neorg.org_file_entered(config.load)
	end
end

-- @Summary Neorg startup function
-- @Description This function gets called after setup() and loads all of the user-defined modules.
-- @Param  module_list (table) - a table that reflects the structure of neorg.configuration.user_configuration.load
function neorg.org_file_entered(module_list)

	vim.opt_local.filetype = "norg"

	-- If no module list was defined, don't do anything
	if not module_list then return end

	-- Loop through all the modules and load them one by one
	require('plenary.async_lib.async').async(function()

		-- Create community module directory
		vim.loop.fs_mkdir(configuration.user_configuration.community_module_path, 16877) -- Permissions: 0775

		-- Add the community-made modules into the package path
		for _, community_module in ipairs(vim.fn.glob(configuration.user_configuration.community_module_path .. "/*", 0, 1, 1)) do
			package.path = package.path .. ";" .. community_module .. "/?.lua"
		end

		-- If the user has defined a post-load hook then execute it
		if configuration.user_configuration.hook then
			configuration.user_configuration.hook()
		end

		-- Go through each defined module and load it
		for name, module in pairs(module_list) do
			if not vim.tbl_isempty(module) and not module.config then
				log.warn("Potential bug detected in", name, "- nonstandard tables found in the module definition. Did you perhaps mean to put these tables inside of the config = {} table?")
			end

			if not neorg.modules.load_module(name, module.config) then
				log.error("Halting loading of modules due to error...")
				break
			end
		end

		-- Goes through each loaded module and invokes neorg_post_load()
		for _, module in pairs(neorg.modules.loaded_modules) do
			module.neorg_post_load()
		end
	end)()()

end

return neorg
