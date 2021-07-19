--[[
--	HELPER FUNCTIONS FOR NEORG
--	This file contains some simple helper function improve quality of life
--]]

neorg.utils = {
	-- @Summary Requires a file from the context of the current module
	-- @Description Allows the module creator to require a file from within the module's cwd
	-- @Param  module (table) - the module creator's module
	-- @Param  filename (string) - a path to the file
	require = function(module, filename)
		return require("neorg.modules." .. module.name .. "." .. filename)
	end,

	-- @Summary Gets the current system username
	-- @Description An OS agnostic way of querying the current user
	get_username = function()
		local current_os = require('neorg.config').os_info

		if not current_os then
			return current_os
		end

		if current_os == "linux" or current_os == "mac" then
			return os.getenv("USER")
		elseif current_os == "windows" then
			return os.getenv("%USERNAME%") -- This should work? lol
		end
	end,
}

return neorg.utils
