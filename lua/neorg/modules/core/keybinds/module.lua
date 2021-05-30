
require('neorg.modules.base')

local module = neorg.modules.create("core.keybinds")

local log = require('neorg.external.log')

module.setup = function()
	return { success = true, requires = { "core.neorgcmd", "core.mode" } }
end

--[[ module.neorg_post_load = function()

end ]]

module.public = {

	neorg_commands = {
		definitions = {
			keybind = {}
		},
		data = {
			keybind = {
				args = 1,
				name = "core.keybinds.trigger"
			}
		},
	},

	keybinds = {
	},

	-- Registers a callback
	register_callback = function(module_name, name)
		local keybind_name = module_name .. "." .. name
		if not module.events.defined[keybind_name] then
			module.events.defined[keybind_name] = neorg.events.define(module, keybind_name)
		end
	end,

	sync = function()

	end

}

module.on_event = function(event)
	if event.type == "core.neorgcmd.events.core.keybinds.trigger" then
		local content = event.content[1]

		if module.events.defined[content] then
			neorg.events.broadcast_event(module, neorg.events.create(module, "core.keybinds.events." .. content))
		else
			log.error("Unable to trigger keybind", content, "- the keybind does not exist")
		end
	end
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		["core.keybinds.trigger"] = true
	}
}

return module
