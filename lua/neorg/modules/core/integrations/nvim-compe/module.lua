--[[
	A module for integrating nvim-compe with Neorg
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.integrations.nvim-compe")

module.private = {
	source = {},
	compe = {},

	completions = {},
}

-- Code to test the existence of nvim-compe
local success, compe =  pcall(require, "compe")

assert(success, "nvim-compe not found, aborting...")

module.private.compe = compe

module.public = {
	create_source = function(user_data)
		user_data = user_data or {}

		local data = {
			name = "[Neorg]",
			priority = 999,
			sort = false,
			dup = 0,
		}

		data = vim.tbl_deep_extend("force", data, user_data)

		module.private.source.new = function()
			return setmetatable({}, { __index = module.private.source })
		end

		module.private.source.get_metadata = function()
			return {
    			priority = data.priority,
    			sort = data.sort,
    			dup = data.dup,
    			filetypes = { "norg" },
    			menu = data.name,
  			}
		end

		module.private.source.determine = function(_, context)
			return module.public.determine(context)
		end

		module.private.source.complete = function(_, context)
			module.public.complete(context)
		end

		module.private.source.confirm = function(_, context)
			module.public.confirm(context)
		end

		module.private.compe.register_source("neorg", module.private.source)
	end,

	determine = function(context)
		local abstracted_context = module.public.create_abstracted_context(context)

		module.private.completion_cache = module.public.invoke_completion_engine(abstracted_context)

		if vim.tbl_isempty(module.private.completion_cache.items) then
			return {}
		end

		if module.private.completion_cache.options.pre then
			module.private.completion_cache.options.pre(abstracted_context)
		end

		local last_whitespace = (context.before_line:reverse()):find("%s")
		last_whitespace = last_whitespace and last_whitespace - 1 or 0

		return { keyword_pattern_offset = context.col - last_whitespace + (module.private.completion_cache.options.index or 0), trigger_character_offset = 1 }
	end,

	complete = function(context)
		if vim.tbl_isempty(module.private.completion_cache.items) then
			return
		end

		local completions = vim.deepcopy(module.private.completion_cache.items)

		for index, element in ipairs(completions) do
			completions[index] = { word = element, kind = module.private.completion_cache.options.type }
		end

		context.callback({
			items = completions
		})
	end,

	confirm = function(context)
		if module.private.completion_cache.options.post then
			module.private.completion_cache.options.post()
		end

		module.private.completion_cache = {}
	end,

	create_abstracted_context = function(context)
		return { start_offset = context.start_offset, char = context.char, before_char = context.before_char, line = context.before_line, column = context.col, buffer = context.bufnr, line_number = context.lnum, previous_context = { line = context.prev_context.before_line, column = context.prev_context.col, start_offset = context.prev_context.start_offset }, full_line = context.line }
	end
}

return module
