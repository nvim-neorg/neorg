--[[
--	COMMAND MODULE TO EXPOSE the :Neorg update command
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.neorgcmd.commands.update")

module.setup = function()
	return { success = true, requires = { "core.neorgcmd", "core.module_manager" } }
end

module.config.public = {
	neorg_commands = {
		definitions = {
			update = {
				modules = {}
			}
		},
		data = {
			update = {
				args = 1,
				subcommands = {

					modules = {
						args = 0,
						name = "update.modules"
					}

				}
			}
		}
	}
}

module.on_event = function(event)
	if event.type == "core.neorgcmd.events.update.modules" then
		module.required["core.module_manager"].update_modules()
	end
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		["update.modules"] = true
	}
}

return module
