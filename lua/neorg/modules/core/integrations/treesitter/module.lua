--[[
	A module designed to integrate TreeSitter into Neorg.
	Currently supports assigning custom Neorg highlight groups to real
	colours.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.integrations.treesitter")

module.setup = function()
	return { success = true, requires = { "core.highlights", "core.mode", "core.keybinds" } }
end

module.config.public = {
	highlights = {
		tag = {
			-- The + tells neorg to link to an existing hl
			begin = "+TSKeyword",

			-- Supply any arguments you would to :highlight here
			-- Example: ["end"] = "guifg=#93042b",
			["end"] = "+TSKeyword",

			name = "+TSKeyword",
			parameters = "+TSType",
			content = "+Normal",
			comment = "+TSComment",
		},

		heading = {
			["1"] = "+TSAttribute",
			["2"] = "+TSLabel",
			["3"] = "+TSMath",
			["4"] = "+TSString",
		},

		error = "+TSError",

		marker = {
			[""] = "+TSLabel",
			title = "+Normal",
		},

		drawer = {
			[""] = "+TSPunctDelimiter",
			title = "+TSMath",
			content = "+Normal"
		},

		escapesequence = "+TSType",

		todoitem = {
			[""] = "+TSCharacter",
			pendingmark = "+TSNamespace",
			donemark = "+TSMethod",
		},

		unorderedlist = "+TSPunctDelimiter",

		quote = {
			[""] = "+TSPunctDelimiter",
			content = "+TSPunctDelimiter",
		},

	}
}

module.load = function()
	module.required["core.highlights"].add_highlights(module.config.public.highlights)
	module.required["core.mode"].add_mode("traverse-heading")
	module.required["core.keybinds"].register_keybinds(module.name, { "next.heading", "previous.heading" })
end

module.public = {
	goto_next_heading = function()
		-- Currently we have this crappy solution because I don't know enough treesitter
		-- If you do know how to hop between TS nodes then please make a PR <3 (or at least tell me)

		local line_number = vim.api.nvim_win_get_cursor(0)[1]

		local lines = vim.api.nvim_buf_get_lines(0, line_number, -1, true)

		for relative_line_number, line in ipairs(lines) do
			local match = line:match("^%s*%*+%s+")

			if match then
				vim.api.nvim_win_set_cursor(0, { line_number + relative_line_number, match:len() })
				break
			end
		end
	end,

	goto_previous_heading = function()
		-- Similar to the previous function I have no clue how to do this in TS lmao
		local line_number = vim.api.nvim_win_get_cursor(0)[1]

		local lines = vim.fn.reverse(vim.api.nvim_buf_get_lines(0, 0, line_number - 1, true))

		for relative_line_number, line in ipairs(lines) do
			local match = line:match("^%s*%*+%s+")

			if match then
				vim.api.nvim_win_set_cursor(0, { line_number - relative_line_number, match:len() })
				break
			end
		end
	end,

	-- @Summary Parses data from an @ tag
	-- @Description Used to extract data from e.g. document.meta
	-- @Param  tag_content (string) - the content of the tag (without the beginning and end declarations)
	parse_tag = function(tag_content)
		local result = {}

		tag_content = tag_content:gsub("([^%s])~\n%s*", "%1 ")

		for name, content in tag_content:gmatch("%s*(%w+):%s+([^\n]*)") do
			result[name] = content
		end

		return result
	end,
}

module.on_event = function(event)
	if event.split_type[1] == "core.keybinds" then
		if event.split_type[2] == "core.integrations.treesitter.next.heading" then
			module.public.goto_next_heading()
		elseif event.split_type[2] == "core.integrations.treesitter.previous.heading" then
			module.public.goto_previous_heading()
		end
	end
end

module.events.subscribed = {
	["core.keybinds"] = {
		["core.integrations.treesitter.next.heading"] = true,
		["core.integrations.treesitter.previous.heading"] = true,
	}
}

return module
