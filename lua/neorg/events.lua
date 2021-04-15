--[[
--	NEORG EVENT FILE
--	This file is responsible for dealing with event handling and broadcasting.
--	All modules that subscribe to an event will receive it once it is triggered.
--]]

local log = require('neorg.external.log')
require('neorg.modules')

require('neorg.external.helpers')

neorg.events = {}

-- Holds the list of events. Events are bound to a module name.
neorg.events.available_events = {}

neorg.events.base_event = {

	type = 'base_event',
	content = nil,
	referrer = nil,

}

function neorg.events.split_event_type(type)

		local start_str, end_str = type:find('%.events%.')

		local split_event_type = { type:sub(0, start_str - 1), type:sub(end_str + 1) }

		if #split_event_type ~= 2 then
				log.warn("Invalid type name:", type)
				return nil
		end

		return split_event_type
end

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

function neorg.events.create_default_event(module, name)

	local new_event = {}

	setmetatable(new_event, { __index = neorg.events.base_event })

	if type then
		new_event.type = name
	end

	new_event.referrer = module

	return new_event

end

function neorg.events.create(module, type)

	local event_template = neorg.events.get_event_template(module, type)

	if not event_template then
		log.warn("Unable to create event of type", type, ". Returning nil...")
		return nil
	end

	local new_event = copy(event_template)

	new_event.type = type
	new_event.referrer = module

	return new_event

end

function neorg.events.broadcast_event(module, event)

	event.referrer = module

	local async

	async = vim.loop.new_async(function()

		local split_event = neorg.events.split_event_type(event.type);

		if not split_event then
			(vim.schedule_wrap(function() log.error("Unable to brodcast event of type", event.type, "; invalid event name") end))()
			return
		end

		for _, current_module in pairs(neorg.modules.loaded_modules) do

			local evt = current_module.events.subscribed[split_event[1]][split_event[2]]

			if evt ~= nil and evt == true then
				current_module.on_event(event)
			end

		end

		async:close()
	end)

	async:send()

end
