--[[
--	NEORG EVENT FILE
--	This file is responsible for dealing with event handling and broadcasting.
--	All modules that subscribe to an event will receive it once it is triggered.
--]]

-- Include the global instance of the logger
local log = require('neorg.external.log')

require('neorg.modules')
require('neorg.external.helpers')

neorg.events = {}

-- Define the base event, all events will derive from this by default
neorg.events.base_event = {

	type = "core.base_event",
	split_type = {},
	content = nil,
	referrer = nil,
	broadcast = true,

	cursor_position = {},
	filename = "",
	filehead = "",
	line_content = ""

}

-- @Summary Splits a full module event path into two
-- @Description The working of this function is best illustrated with an example:
--		If type == 'core.some_plugin.events.my_event', this function will return { 'core.some_plugin', 'my_event' }
-- @Param  type (string) - the full path of a module event
function neorg.events.split_event_type(type)

		local start_str, end_str = type:find("%.events%.")

		local split_event_type = { type:sub(0, start_str - 1), type:sub(end_str + 1) }

		if #split_event_type ~= 2 then
				log.warn("Invalid type name:", type)
				return nil
		end

		return split_event_type
end

-- @Summary Returns an event template as defined by a module
-- @Description Returns an event template defined in module.events.defined
-- @Param  module (table) - a reference to the module invoking the function
-- @Param  type (string) - a full path to a valid event type (e.g. 'core.module.events.some_event')
function neorg.events.get_event_template(module, type)

    if not neorg.modules.is_module_loaded(module.name) then
		log.info("Unable to get event of type", type, "with module", module.name)
		return nil
	end

	local split_type = neorg.events.split_event_type(type)

	if not split_type then
		log.warn("Unable to get event template for event", type, "and module", module.name)
		return nil
	end

	log.trace("Returning", split_type[2], "for module", split_type[1])

	if module.name ~= split_type[1] then
		log.error("Unauthorized access to event type", type, ". Module name (" .. module.name .. ") does not match", split_type[1])
		return nil
	end

	return neorg.modules.loaded_modules[module.name].events.defined[split_type[2]]

end

-- @Summary Creates an event that derives from neorg.events.base_event
-- @Description Creates a deep copy of the neorg.events.base_event event and returns it with a custom type and referrer
-- @Param  module (table) - a reference to the module invoking the function
-- @Param  name (string) - a full path to a valid event type (e.g. 'core.module.events.some_event')
function neorg.events.define_event(module, name)

	local new_event = {}

	new_event = vim.deepcopy(neorg.events.base_event)

	if type then
		new_event.type = name
	end

	new_event.referrer = module.name

	return new_event

end

-- @Summary Creates an instance of an event type
-- @Description Returns a copy of the event template provided by a module
-- @Param  module (table) - a reference to the module invoking the function
-- @Param  type (string) - a full path to a valid event type (e.g. 'core.module.events.some_event')
-- @Param  content (any) - the content of the event, can be anything from a string to a table to whatever you please
function neorg.events.create(module, type, content)

	local event_template = neorg.events.get_event_template(module, type)

	if not event_template then
		log.warn("Unable to create event of type", type, ". Returning nil...")
		return nil
	end

	local new_event = copy(event_template)

	new_event.type = type
	new_event.content = content
	new_event.referrer = module.name

	return new_event

end

-- @Summary Broadcasts an event
-- @Description Sends an event to all subscribed modules. The event contains the filename, filehead, cursor position and line content as a bonus.
-- @Param  module (table) - a reference to the module invoking the function. Used to verify the authenticity of the function call
-- @Param  event (table) - an event, usually created by neorg.events.create()
function neorg.events.broadcast_event(module, event)

	event.split_type = neorg.events.split_event_type(event.type)
	event.filename = vim.fn.expand("%:t")
	event.filehead = vim.fn.expand("%:p:h")
	event.cursor_position = vim.api.nvim_win_get_cursor(0)
	event.line_content = vim.api.nvim_get_current_line()
	event.referrer = module.name
	event.broadcast = true

	local async

	async = vim.loop.new_async(function()

		if not event.split_type then
			log.error("Unable to broadcast event of type", event.type, "; invalid event name")
			return
		end

		for _, current_module in pairs(neorg.modules.loaded_modules) do

			if current_module.events.subscribed and current_module.events.subscribed[event.split_type[1]] then

				local evt = current_module.events.subscribed[event.split_type[1]][event.split_type[2]]

				if evt ~= nil and evt == true then
					current_module.on_event(event)
				end

			end

		end

		async:close()
	end)

	async:send()

end

-- @Summary Sends an event to an individual module
-- @Description Instead of broadcasting to all loaded modules, send_event() only sends to one module
-- @Param  module (table) - a reference to the module invoking the function. Used to verify the authenticity of the function call
-- @Param  recipient (string) - the name of a loaded module that will be the recipient of the event
-- @Param  event (table) - an event, usually created by neorg.events.create()
function neorg.events.send_event(module, recipient, event)

	event.split_type = neorg.events.split_event_type(event.type)
	event.filename = vim.fn.expand("%:t")
	event.filehead = vim.fn.expand("%:p:h")
	event.cursor_position = vim.api.nvim_win_get_cursor(0)
	event.line_content = vim.api.nvim_get_current_line()
	event.referrer = module.name
	event.broadcast = false

	if not neorg.modules.is_module_loaded(recipient) then
		log.warn("Unable to send event to module", recipient, "- the module is not loaded.")
		return
	end

	local mod = neorg.modules.loaded_modules[recipient]

	if mod.events.subscribed and mod.events.subscribed[event.split_type[1]] then

		local evt = mod.events.subscribed[event.split_type[1]][event.split_type[2]]

		if evt ~= nil and evt == true then
			mod.on_event(event)
		end

	end


end
