--[[
--	KEYBINDS MODULE FOR NEORG
--	This module implements the ability to bind keys to events

USAGE:

	In your module.setup(), make sure to require 'core.keybinds'
	Define public keymaps inside the config.public.keybinds
	These will be able to be overwritten by the user in the setup() function

	config.public.keybinds = {

			["<C-s>"] = {
				mode = "n",
				name = "some_keymap_name",
				opts = { silent = false, noremap = false, expr = false }
			}

	}

--]]

require('neorg.modules.base')
require('neorg.modules')

local log = require('neorg.external.log')

local module_keybinds = neorg.modules.create("core.keybinds")

function _neorg_module_keybinds_callback(module_name, name)
	neorg.events.send_event(module_keybinds, module_name, neorg.events.create(module_keybinds, name, nil))
end

module_keybinds.config.public.keybinds = {}

module_keybinds.neorg_post_load = function()

	for _, module in pairs(neorg.modules.loaded_modules) do
		module_keybinds.public.register_keybinds(module.name)
	end

end

module_keybinds.public = {

	register_keybinds = function(module_name)

		local public_module_config = neorg.modules.get_module_config(module_name)

		if not public_module_config or not public_module_config.keybinds or vim.tbl_isempty(public_module_config.keybinds) then return false end

		for name, key in pairs(public_module_config.keybinds) do

			if module_keybinds.events.defined[name] then
				log.warn("Unable to set keybind", name, "for module", module_name, "- the specified key is already bound to", module_keybinds.events.defined[name].name or "something else")
			else
				local event_name = module_name .. '.' .. key.name
				module_keybinds.events.defined[event_name] = neorg.events.define_event(module_keybinds, event_name);
				(vim.schedule_wrap(function() vim.api.nvim_set_keymap(key.mode, name, ":lua _neorg_module_keybinds_callback(\"" .. module_name .. "\", \"core.keybinds.events." .. event_name .. "\")<CR>", key.opts) end))()
			end

		end

		return true
	end

}

return module_keybinds
