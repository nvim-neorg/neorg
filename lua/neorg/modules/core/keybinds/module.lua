
require('neorg.modules.base')

local module = neorg.modules.create("core.keybinds")

local log = require('neorg.external.log')

module.setup = function()
	return { success = true, requires = { "core.neorgcmd", "core.mode" } }
end

module.public = {

	neorg_commands = {
		definitions = {
			keybind = {}
		},
		data = {
			keybind = {
				args = 2,
				name = "core.keybinds.trigger"
			}
		},
	},

	keybinds = {},

	-- Registers a callback
	register_callback = function(module_name, name)
		local keybind_name = module_name .. "." .. name
		if not module.events.defined[keybind_name] then
			module.events.defined[keybind_name] = neorg.events.define(module, keybind_name)

			module.public.keybinds[keybind_name] = {}
		end
	end,

	sync = function()
		local modes = module.required["core.mode"].get_modes()

		for _, mode in ipairs(modes) do
			module.public.neorg_commands.definitions.keybind[mode] = module.public.keybinds
		end

		module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands.definitions.keybind)

		log.warn(module.public.neorg_commands.definitions)
	end

}

module.neorg_post_load = module.public.sync

module.on_event = function(event)
	if event.type == "core.neorgcmd.events.core.keybinds.trigger" then
		local keybind_event_path = event.content[2]

		if module.events.defined[keybind_event_path] then
			neorg.events.broadcast_event(module, neorg.events.create(module, "core.keybinds.events." .. keybind_event_path))
		else
			log.error("Unable to trigger keybind", keybind_event_path, "- the keybind does not exist")
		end
	end
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		["core.keybinds.trigger"] = true
	}
}

return module
