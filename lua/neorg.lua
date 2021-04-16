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

	local ext = vim.fn.expand('%:e')

	if ext == 'org' or ext == 'norg' then neorg.org_file_entered() end
end

function neorg.org_file_entered()
	-- neorg.modules.load_module('core.autocommands', 'bruh/moment')
	neorg.modules.load_module('core.test', 'bruh/moment')
end

return neorg
