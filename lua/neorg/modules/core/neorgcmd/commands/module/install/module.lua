--[[
-- GitHub installer for neorg modules (WIP)
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.neorgcmd.commands.install")

local log = require('neorg.external.log')

module.setup = function()
	return { success = true, requires = { "core.module_manager" } }
end

module.config.public = {

	neorg_commands = {
		definitions = {
			install = {}
		},
		data = {
			install = {
				min_args = 1,
				name = "install"
			}
		}
	}

}

module.on_event = function(event)

	-- We know that the only event we will be receiving will be the install event, since that's the only event we're subscribed to

	-- Concatenate the arguments we have received from :Neorg install into the full shortened git address
	local shortened_git_address = (function()
		local res = ""
		for i, string in ipairs(event.content) do res = res .. string .. (i < #event.content and " " or "") end
		return res
	end)()

	module.required["core.module_manager"].install_module(shortened_git_address)
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		install = true
	}
}

return module
