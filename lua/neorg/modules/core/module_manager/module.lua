--[[
--	MODULE MANAGER FOR NEORG
--	This module is responsible for managing and updating community-provided modules
--	in a path of the user's choice.
--	This module uses the core.gitgrabber module under the hood.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.module_manager")

local config = require('neorg.config')

module.setup = function()
	return { success = true, requires = { "core.gitgrabber" } }
end

module.public = {

	-- @Summary Updates all community-provided modules
	-- @Description Utilizes the gitgrabber module to pull updates from github for all community modules
	update_modules = function()
		-- Update all community-made modules
		for _, community_module in ipairs(vim.fn.glob(config.user_configuration.community_module_path .. "/*", 0, 1, 1)) do
			module.required["core.gitgrabber"].update(community_module)
		end
	end,

	-- @Summary Installs or updates a module from github
	-- @Description If the repo does not already exist then it gets installed and auto-manged by core.module_manager. Otherwise it is simply updated.
	-- @Param  repo (string) - a shortened repo address, like/this
	install_module = function(repo)
		-- Manage the repo and check whether it has a "neorg" subdirectory. If it does then it means it's a valid module.
		return module.required["core.gitgrabber"].manage(repo, config.user_configuration.community_module_path, function(install_location)
			return install_location .. "/neorg", "not a valid neorg module"
		end)
	end

}

return module
