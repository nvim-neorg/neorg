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
	end
}

return neorg.utils
