neorg = {}

require('neorg.events')
require('neorg.modules')

neorg.configuration = {}
neorg.configuration.os_info = (function()

	if vim.fn.has('win32') == 1 then
		return 'windows'
	elseif vim.fn.has('unix') == 1 then
		return 'linux'
	elseif vim.fn.has('mac') == 1 then
		return 'mac'
	end

end)()

function neorg.setup(config)
	neorg.configuration.user_configuration = config and config or { use_keybindings = true, invocation_key = "<Leader>" }

	module = neorg.modules.create('core.test')

	module.load = function(modules, count)
		return { loaded = true, subscribed_events = { 'bruh' } }
	end

	module.on_event = function(event)
		require('neorg.external.log').warning("I got IT!")
	end

	neorg.modules.load_module(module)
	neorg.events.broadcast_event(neorg.events.create('bruh'))
end

return neorg
