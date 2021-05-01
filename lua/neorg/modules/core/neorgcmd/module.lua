--[[

--]]


require('neorg.modules.base')
require('neorg.modules')
require('neorg.events')

local log = require('neorg.external.log')

local module = neorg.modules.create("core.neorgcmd")

function _neorgcmd_generate_completions(_, command)

	if not neorg.modules.is_module_loaded("core.neorgcmd") then
		return { "Unable to provide completions: core.neorgcmd is not loaded." }
	end

	local neorgcmd_module = require('neorg.modules.core.neorgcmd.module')

	local split_command = vim.split(command, " ")

	local ref = neorgcmd_module.config.public.functions.definitions

	if #split_command == 2 then
		return vim.tbl_keys(ref)
	end

	for _, cmd in ipairs(vim.list_slice(split_command, 2)) do
		if ref[cmd] then ref = ref[cmd] else break end
	end

	return vim.tbl_keys(ref)
end

module.load = function()
	vim.cmd [[ command! -nargs=+ -complete=customlist,v:lua._neorgcmd_generate_completions Neorg :lua require('neorg.modules.core.neorgcmd.module').public.function_callback(<f-args>) ]]
end

module.config.public = {

	functions = {
		definitions = {
			list = {
				modules = {}
			}
		},
		data = {
			list = {
				args = 1,

				subcommands = {

					modules = {
						args = 0
					}

				}
			}
		}
	}

}

module.public = {

	add_subcommands = function(subcommands)
		module.config.public.functions = vim.tbl_deep_extend("force", module.config.public.functions, subcommands)
	end,

	function_callback = function(...)
		local args = { ... }

		local ref_definitions = module.config.public.functions.definitions
		local ref_data = module.config.public.functions.data
		local ref_data_one_above = module.config.public.functions.data
		local event_name = "core.neorgcmd.events"
		local current_depth = 0

		for _, cmd in ipairs(args) do
			if ref_definitions[cmd] then
				if ref_data[cmd] then

					ref_data_one_above = ref_data[cmd]

					ref_definitions = ref_definitions[cmd]
					event_name = event_name .. "." .. cmd
					current_depth = current_depth + 1

					if ref_data[cmd].subcommands then
						ref_data = ref_data[cmd].subcommands
					else
						break
					end

				else
					log.error("Unable to execute neorg command under the name", event_name .. "." .. cmd, "- the command exists but doesn't hold any valid metadata. Metadata is required for neorg to parse the command correctly, please consult the neorg wiki if you're confused.")
					return
				end
			else
				log.error("Unable to execute neorg command under the name", event_name .. "." .. cmd, "- such a command does not exist.")
				return
			end
		end

		ref_data_one_above.min_args = ref_data_one_above.min_args or 0

		if ref_data_one_above.args then
			ref_data_one_above.min_args = ref_data_one_above.args
			ref_data_one_above.max_args = ref_data_one_above.args
		end

		if #args - current_depth < ref_data_one_above.min_args then
			log.error("Unable to execute neorg command under name", event_name, "- minimum argument count not satisfied. The command requires at least", ref_data_one_above.min_args, "arguments.")
			return
		end

		if ref_data_one_above.max_args and #args - current_depth > ref_data_one_above.max_args then
			if ref_data_one_above.max_args == 0 then
				log.error("Unable to execute neorg command under name", event_name, "- exceeded maximum argument count. The command does not take any arguments.")
			else
				log.error("Unable to execute neorg command under name", event_name, "- exceeded maximum argument count. The command does not allow more than", ref_data_one_above.max_args, "arguments.")
			end

			return
		end

		local relative_path = event_name:sub(("core.neorgcmd.events."):len() + 1)

		module.events.defined[relative_path] = neorg.events.define(module, relative_path)

		neorg.events.broadcast_event(module, neorg.events.create(module, event_name, vim.list_slice(args, #args - (#args - current_depth) + 1)))
	end,

	set_completion_callback = function(callback)
		_neorgcmd_generate_completions = callback
	end

}

--[[
-- Create completions and bind to functions using a public function
-- Whenever a module wants to implement its own custom functionality all it has to do is require core.neorgcmd and add a hook using the aforementioned public func
-- Completion will then be dynamically generated and the relevant function will be invoked accordingly
--]]

return module
