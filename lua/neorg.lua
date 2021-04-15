neorg = {}

require('neorg.events')
require('neorg.modules')

neorg.configuration = {}
neorg.configuration.user_configuration = {}
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
	neorg.configuration.user_configuration = vim.tbl_deep_extend("force", config or {}, neorg.configuration.user_configuration)

	local log = require('neorg.external.log')

	log.new(neorg.configuration.user_configuration.logger or log.get_default_config(), true)

	module = neorg.modules.create('core.test')

	module.load = function()
		return { success = true }
	end

	module.on_event = function(event)
		(vim.schedule_wrap(function() require('neorg.external.log').warn("AYO") end))()
	end

	module.events.defined = { ['test_event'] = neorg.events.create_default_event(module, 'test_event') }

	module.events.subscribed = {
		['core.test'] = { test_event = true }
	}

	neorg.modules.load_module_from_table(module)

	local event = neorg.events.create(module, 'core.test.events.test_event')
	neorg.events.broadcast_event(module, event)

	neorg.modules.load_module('core.autocommands', 'bruh/moment')
end

return neorg
