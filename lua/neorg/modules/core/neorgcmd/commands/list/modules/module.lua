--[[
-- LIST.MODULES module for NEORGCMD
-- Usage:
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.neorgcmd.commands.list.modules")

module.setup = function()
	return { success = true, requires = { "core.neorgcmd" } }
end

module.neorg_post_load = function()
	module.required["core.neorgcmd"].add_commands(module.name)
end

module.config.public = {

	neorg_commands = {
		definitions = {
			list = {
				modules = {}
			}
		},
		data = {
			list = {
				args = 1,

				subcommands = {

					modules = {
						args = 0,
						name = "list.modules"
					}

				}
			}
		}
	}

}

module.on_event = function(event)
	if event.type == "core.neorgcmd.events.list.modules" then

		(vim.schedule_wrap(function() vim.cmd("echom \"--- PRINTING ALL LOADED MODULES ---\"") end))()

		for _, module in pairs(neorg.modules.loaded_modules) do
			(vim.schedule_wrap(function() vim.cmd("echom \"" .. module.name .. "\"") end))()
		end

		(vim.schedule_wrap(function() vim.cmd("echom \"Execute :messages to see output. BETA PRINTER FOR LOADED MODULES. This is obviously not final :P. Soon modules will be shown in a floating window.\"") end))()
	end
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		["list.modules"] = true
	}
}

return module
