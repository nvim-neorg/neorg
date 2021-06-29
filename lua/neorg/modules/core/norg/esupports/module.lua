--[[
	Module for supporting the user while editing. Esupports -> Editing Supports
	Currently provides custom and configurable indenting for Neorg files

USAGE:
	Esupports is part of the `core.defaults` metamodule, and hence should be available to most
	users right off the bat.
CONFIGURATION:
	<TODO>
REQUIRES:
	`core.autocommands` - for detecting whenever a new .norg file is entered
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.esupports")

function _neorg_indent_expr()
	local line_number = vim.fn.prevnonblank(vim.api.nvim_win_get_cursor(0)[1] - 1)

	-- If the line number above us is 0 then don't indent anything
	if line_number == 0 then
		return 0
	end

	-- nvim_buf_get_lines() doesn't work here for some reason :(
	local line = vim.fn.getline(line_number)

	-- @Summary Creates a new indent
	-- @Description Sets a new set of rules that when fulfilled will indent the text properly
	-- @Param  match (string) - a regex that should match the line above the newly placed line
	-- @Param  indent (function(matches) -> number) - a function that should return the level of indentation in spaces for that line
	local create_indent = function(match, indent)

		-- Pack all the matches into this lua table
		local matches = { line:match(match) }

		-- If we have indenting enabled and if the match is successful
		if module.config.public.indent and matches[1] then
			-- Invoke the callback for indenting
			local indent_amount = indent(matches)

			-- If the return value of the callback is -1, make neovim automatically indent the next line
			-- Else, use the returned indent amount to calculate a new value, one that will work with any
			-- size of tabs
			indent_amount = indent_amount == -1 and vim.fn.indent(line) or indent_amount + (vim.fn.strdisplaywidth(line) - line:len())

			-- Return success
			return indent_amount, true
		end

		-- If we haven't found a match, return nothing
		return nil, false
	end

	local indent_amount, success

	-- For every defined element in the indent configuration
	for _, data in pairs(module.config.public.indent_config) do
		-- Check whether the line matches any of our criteria
		indent_amount, success = create_indent(data.regex, data.indent)
		-- If it does, then return that indent!
		if success then return indent_amount end
	end

	-- If no criteria were met, let neovim handle the rest
	return vim.fn.indent(line_number)
end

module.setup = function()
	return { success = true, requires = { "core.autocommands" } }
end

module.config.public = {
	indent = true,

	indent_config = {
		todo_items = {
			regex = "^(%s*)%-%s+%[%s*[x%*%s]%s*%]%s+.*$",
			indent = function(matches)
				return matches[1]:len()
			end
		},

		headings = {
			regex = "^(%s*%*+%s+)(.*)$",
			indent = function(matches)
				if matches[2]:len() > 0 then
					return matches[1]:len()
				else
					return -1
				end
			end
		},

		quotes = {
			regex = "^(%s*>%s+)(.*)$",
			indent = function(matches)
				if matches[2]:len() > 0 then
					return matches[1]:len()
				else
					return -1
				end
			end
		},

		unordered_lists = {
			regex = "^(%s*)%-%s+.+$",
			indent = function(matches)
				return matches[1]:len()
			end
		},

	}
}

module.load = function()
	module.required["core.autocommands"].enable_autocommand("BufEnter")
end

module.on_event = function(event)
	if event.type == "core.autocommands.events.bufenter" then
		if event.content then
			vim.opt_local.indentexpr = "v:lua._neorg_indent_expr()"
		end
	end
end

module.events.subscribed = {
	["core.autocommands"] = {
		bufenter = true,
	}
}

return module
