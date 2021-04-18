neorg = {}

require('neorg.events')
require('neorg.modules')

neorg.configuration = {

	user_configuration = {
		load = {
			--[[
				["name"] = { git_address = "address", config = { ... } }
			--]]
		},
	},

}

neorg.configuration.os_info = (function()

	if vim.fn.has("win32") == 1 then
		return "windows"
	elseif vim.fn.has("unix") == 1 then
		return "linux"
	elseif vim.fn.has("mac") == 1 then
		return "mac"
	end

end)()

function neorg.setup(config)
	neorg.configuration.user_configuration = config or {}

	require('neorg.external.log').new(neorg.configuration.user_configuration.logger or log.get_default_config(), true)

	local ext = vim.fn.expand("%:e")

	if ext == "org" or ext == "norg" then neorg.org_file_entered(config.load) end
end

function neorg.org_file_entered(module_list)

	if not module_list then return end

	for name, module in pairs(module_list) do
		if not neorg.modules.load_module(name, module.git_address, module.config) then
			log.error("Halting loading of modules due to error...")
			break
		end
	end

	local async

	async = vim.loop.new_async(function()

		for _, module in pairs(neorg.modules.loaded_modules) do
			module.neorg_post_load()
		end

		async:close()

	end)

	async:send()

end

return neorg
