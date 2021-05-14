--[[
--	KEYBINDS MODULE FOR NEORG
--	This module implements the ability to bind keys to events

USAGE:

	In your module.setup(), make sure to require 'core.keybinds'
	Define public keymaps inside config.public.keybinds
	These will be able to be overwritten by the user in the setup() function

	config.public.keybinds = {

		["all"] = { -- Define these keybinds for all neorg modes
			["<C-s>"] = {
				mode = "n",
				name = "some_keymap_name",
				prefix = nil|false|true,
				opts = { silent = false, noremap = false, expr = false }
			}
		}
	}

	When you receive an event, it will come in this format:
	{
		type = "core.keybinds.events.<full_module_path>.<value of ["<C-s>"].name>",
		split_type = { "core.keybinds", "<full_module_path>.<value of ["<C-s>"].name>" },
		broadcast = false
	}

For more info, consult the wiki entry here: <insert link when it's done>

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

module_keybinds.setup = function()
	return { success = true, requires = { "core.mode" } }
end

module_keybinds.private = {
	registered_keybinds = {},

	-- @Summary Handles the binding of keys
	-- @Description By default is a wrapper around vim.api.nvim_buf_set_keymap, defines a key
	-- @Param  module_name (string) - the name of the module who binds the key
	-- @Param  keybind (string) - the actual keybind, e.g. <Leader>o
	-- @Param  key (table) - a key as created by register_keybinds
	key_bind_handler = function(module_name, keybind, key)

		local event_name = module_name .. '.' .. key.name
		vim.api.nvim_buf_set_keymap(0, key.mode, keybind, ":lua _neorg_module_keybinds_callback(\"" .. module_name .. "\", \"core.keybinds.events." .. event_name .. "\")<CR>", key.opts)

	end,

	-- @Summary Handles the unbinding of keys
	-- @Description By default wraps vim.api.nvim_buf_del_keymap, deletes a key
	-- @Param  mode (string) - the mode of the key to unbind, e.g. "n", "v", "i"
	-- @Param  keybind (string) - the keybind, e.g. <Leader>o
	key_unbind_handler = function(mode, keybind)
		vim.api.nvim_buf_del_keymap(0, mode, keybind)
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

		-- If the module we want to pull from does not have the right tables defined then don't bother
		if not public_module_config or not public_module_config.keybinds or vim.tbl_isempty(public_module_config.keybinds) then return false end

		-- Get the current and previous neorg mode
		local current_mode = module_keybinds.required["core.mode"].get_mode()
		local previous_mode = module_keybinds.required["core.mode"].get_previous_mode()

		-- If the current module does not have keybinds for the current mode, then set read the "all" table
		if not public_module_config.keybinds[current_mode] then
			if public_module_config.keybinds["all"] then
				current_mode = "all"
			end
		end

		-- If we have leftover keybinds from the previous mode then unbind all of them
		if module_keybinds.private.registered_keybinds[previous_mode] then
			for _, key in pairs(module_keybinds.private.registered_keybinds[previous_mode]) do
				vim.schedule(function() module_keybinds.private.key_unbind_handler(key.key.mode, key.keybind) end)
			end
		end

		-- If the table containing keybinds doesn't exist then leave
		if not public_module_config.keybinds[current_mode] then return true end

		-- If the registered_keybinds table for the current mode doesn't exist then define it
		if not module_keybinds.private.registered_keybinds[current_mode] then
			module_keybinds.private.registered_keybinds[current_mode] = {}
		end

		-- This variable tells the below for loop how many keybinds to loop over
		local available_keybinds = public_module_config.keybinds[current_mode]

		-- If the current module we're iterating over has an "all" table and the current mode is different than "all"
		-- then concatenate both the "all" table and the keybinds from the current mode
		if public_module_config.keybinds["all"] and current_mode ~= "all" then
			available_keybinds = vim.tbl_deep_extend("force", public_module_config.keybinds["all"], public_module_config.keybinds[current_mode])
		end

		--[[
		--	Add all the keybinds. This process does not actually register the keybinds,
		--	but rather stores them in a list. The reason it does this is because
		--	keybinds of the same name can be overrwritten, so we make sure all the overrwrites happen first,
		--	then the actual registration of the keybinds can commence.
		--]]
		for name, key in pairs(available_keybinds) do

			-- Check if the key has been bound before
			local old_keybind = module_keybinds.private.registered_keybinds[current_mode][key.name]

			-- If the prefix variable has not been defined, contextually set it to the default value
			if key.prefix == nil then
				-- If the string does not begin with "<" then prepend the prefix
				key.prefix = (name:sub(1, 1) ~= "<")
			end

			-- If it has been bound before, unbind the old key and rebind the new version
			if old_keybind then

				log.trace("Overriding keybind", old_keybind.keybind, "with new keybind", name, "for module", module_name)

				-- Since the event type is supposed to look like core.keybinds.events.<module_name>.<keybind_name>, we construct it here
				local event_name = module_name .. '.' .. key.name

				-- Undefine the previously defined keybind
				module_keybinds.events.defined[module_name .. '.' .. old_keybind.key.name] = nil

				-- Add the new keybind
				module_keybinds.events.defined[event_name] = neorg.events.define(module_keybinds, event_name)

				module_keybinds.private.registered_keybinds[current_mode][key.name] = { keybind = key.prefix and (module_keybinds.config.public.prefix .. name) or name, key = key }
			else
				log.trace("Adding keybind", name, "for module", module_name)

				-- Otherwise just add the key to the list normally
				local event_name = module_name .. '.' .. key.name
				module_keybinds.events.defined[event_name] = neorg.events.define(module_keybinds, event_name)
				module_keybinds.private.registered_keybinds[current_mode][key.name] = { keybind = key.prefix and (module_keybinds.config.public.prefix .. name) or name, key = key }
			end
		end

		-- Afterwards, go through all the parsed keys and actually register them
		for _, key in pairs(module_keybinds.private.registered_keybinds[current_mode]) do
			log.trace("Registering keybind", key.keybind, "for module", module_name)

			vim.schedule(function() module_keybinds.private.key_bind_handler(module_name, key.keybind, key.key) end)
		end

		return true
	end,

	-- @Summary Changes the inbuilt key bind handler
	-- @Description The key bind handler gets invoked whenever a keybind needs to get assigned (bound). By default it's just a wrapper around nvim_buf_set_keymap()
	-- @Param  key_bind_handler (function(module_name, keybind, key)) - the function to be invoked
	--		module_name (string) - the name of the module whose keybind will be bound to
	--		keybind (string) - the actual key (e.g. <Leader>oid)
	--		key (table) - data about the key itself; consists of name, mode and opts fields
	set_key_bind_handler = function(key_bind_handler)
		module_keybinds.private.key_bind_handler = key_bind_handler
	end,

	-- @Summary Changes the inbuilt key unbind handler
	-- @Description The key unbind handler gets invoked whenever all keybinds from a specific mode need to get deleted from a buffer. By default it's just a wrapper around nvim_buf_del_keymap()
	-- @Param  key_unbind_handler (function(mode)) - the function to be invoked
	--		mode - the mode from which to unbind all keymaps
	set_key_unbind_handler = function(key_unbind_handler)
		module_keybinds.private.key_unbind_handler = key_unbind_handler
	end,

	-- @Summary Reparses all keybinds from every loaded module
	-- @Description Synchronizes changes made in the keybind tables and rebinds all keys
	sync = function()
		-- Go through every loaded module and unregister its keybinds.
		for _, module in pairs(neorg.modules.loaded_modules) do
			module_keybinds.public.register_keybinds(module.name)
		end
	end,

	version = "0.1.0"

}

module_keybinds.neorg_post_load = module_keybinds.public.sync

module_keybinds.on_event = function(event)
	-- If the neorg mode has changed then
	if event.type == "core.mode.events.mode_set" then
		module_keybinds.public.sync()
	end
end

module_keybinds.events.subscribed = {
	["core.mode"] = {
		mode_set = true
	}
}

return module_keybinds
