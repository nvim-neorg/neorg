--[[
--	KEYBINDS MODULE FOR NEORG
--	This module implements the ability to bind keys to events

USAGE:

	In your module.setup(), make sure to require 'core.keybinds'
	Define public keymaps inside config.public.keybinds
	These will be able to be overwritten by the user in the setup() function

	config.public.keybinds = {

			["<C-s>"] = {
				mode = "n",
				name = "some_keymap_name",
				prefix = false,
				opts = { silent = false, noremap = false, expr = false }
			}

	}

	When you receive an event, it will come in this format:
	{
		type = "core.keybinds.events.<full_module_path>.<value of ["<C-s>"].name>",
		split_type = { "core.keybinds", "<full_module_path>.<value of ["<C-s>"].name>" },
		broadcast = false
	}

--]]

require('neorg.modules.base')
require('neorg.modules')

local log = require('neorg.external.log')

local module_keybinds = neorg.modules.create("core.keybinds")

-- @Summary Keybind callback
-- @Description This function gets called whenever a registered keybind is pressed. Note that this is used internally by core.keybinds and shouldn't be used by the user.
-- @Param  module_name (string) - the module name of the recipient
-- @Param  name (string) - the name (type) of the event
function _neorg_module_keybinds_callback(module_name, name)
	neorg.events.send_event(module_keybinds, module_name, neorg.events.create(module_keybinds, name, nil))
end

module_keybinds.neorg_post_load = function()

	-- Register keybinds for all modules after they have been loaded
	for _, module in pairs(neorg.modules.loaded_modules) do
		module_keybinds.public.register_keybinds(module.name)
	end

end

module_keybinds.private = {
	registered_keybinds = {},
	key_handler = function(module_name, keybind, key)

		local event_name = module_name .. '.' .. key.name
		vim.api.nvim_set_keymap(key.mode, keybind, ":lua _neorg_module_keybinds_callback(\"" .. module_name .. "\", \"core.keybinds.events." .. event_name .. "\")<CR>", key.opts)

	end
}

module_keybinds.config.public = {

	prefix = "<Leader>o",

}

module_keybinds.public = {

	-- @Summary Registers a keybind for a certain module
	-- @Description Reads the module.config.public.keybinds table and registers keybinds for all the contained entries
	-- @Param  module_name (string) - the name of a loaded module
	register_keybinds = function(module_name)

		-- Get the public module configuration, if one cannot be grabbed then exit
		local public_module_config = neorg.modules.get_module_config(module_name)

		if not public_module_config or not public_module_config.keybinds or vim.tbl_isempty(public_module_config.keybinds) then return false end

		--[[
		--	Add all the keybinds. This process does not actally register the keybinds,
		--	but rather stores them in a list. The reason it does this is because
		--	keybinds of the same name can be overrwritten, so we make sure all the overrwrites happen first,
		--	then the actual registration of the keybinds can commence.
		--]]
		for name, key in pairs(public_module_config.keybinds) do

			-- Check if the key has been bound before
			local old_keybind = module_keybinds.private.registered_keybinds[key.name]

			-- If the prefix variable has not been defined, contextually set it to the default value
			if key.prefix == nil then
				-- If the string does not being with "<" then prepend the prefix
				key.prefix = (name:sub(1, 1) ~= "<")
			end

			-- If it has, unbind the old key and rebind the new version
			if old_keybind then

				log.trace("Overriding keybind", old_keybind.keybind, "with new keybind", name, "for module", module_name)

				-- Since the event type is supposed to look like core.keybinds.events.<module_name>.<keybind_name>, we construct it here
				local event_name = module_name .. '.' .. key.name

				-- Undefine the previously defined keybind
				module_keybinds.events.defined[module_name .. '.' .. old_keybind.key.name] = nil

				-- Add the new keybind
				module_keybinds.events.defined[event_name] = neorg.events.define(module_keybinds, event_name)

				module_keybinds.private.registered_keybinds[key.name] = { keybind = key.prefix and (module_keybinds.public.prefix .. name) or name, key = key }
			else
				log.trace("Adding keybind", name, "for module", module_name)

				-- Otherwise just add the key to the list normally
				local event_name = module_name .. '.' .. key.name
				module_keybinds.events.defined[event_name] = neorg.events.define(module_keybinds, event_name)
				module_keybinds.private.registered_keybinds[key.name] = { keybind = key.prefix and (module_keybinds.public.prefix .. name) or name, key = key }
			end
		end

		-- Afterwards, go through all the parsed keys and actually register them
		for _, key in pairs(module_keybinds.private.registered_keybinds) do
			log.trace("Registering keybind", key.keybind, "for module", module_name);

			(vim.schedule_wrap(function() module_keybinds.private.key_handler(module_name, key.keybind, key.key) end))()
		end

		return true
	end,

	-- @Summary Changes the inbuilt key handler
	-- @Description The key handler gets invoked whenever a keybind needs to get assigned. By default it's just a wrapper around nvim_set_keymap()
	-- @Param  key_handler (function(module_name, keybind, key)) - the function to be invoked
	--		module_name (string) - the name of the module whose keybind will be bound to
	--		keybind (string) - the actual key (e.g. <Leader>oid)
	--		key (table) - data about the key itself; consists of name, mode and opts fields
	set_key_handler = function(key_handler)
		module_keybinds.private.key_handler = key_handler
	end

}

return module_keybinds
