--[[
-- GitHub installer for neorg modules (WIP)
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.neorgcmd.commands.install")

module.config.public = {

	neorg_commands = {
		definitions = {
			install = {}
		},
		data = {
			install = {
				args = 1,
				name = "install"
			}
		}
	}

}

module.on_event = function(event)

	-- We know that the only event we will be receiving will be the install event, since that's the only event we're subscribed to


end

module.events.subscribed = {
	["core.neorgcmd"] = {
		install = true
	}
}

return module
