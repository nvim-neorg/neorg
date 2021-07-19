--[[
	CONCEALER MODULE FOR NEORG.
	This module is supposed to enhance the neorg editing experience
	by abstracting away certain bits of text and concealing it into one easy-to-recognize
	icon. Icons can be easily changed and every element can be disabled.

USAGE:
	This module does not come bundled by default with the core.defaults metamodule.
	Make sure to manually enable it in neorg's setup function.

	The module comes with several config options, and they are listed here:
	icons = {
		todo = {
			enabled = true, -- Conceal TODO items

			done = {
				enabled = true, -- Conceal whenever an item is marked as done
				icon = ""
			},
			pending = {
				enabled = true, -- Conceal whenever an item is marked as pending
				icon = ""
			},
			undone = {
				enabled = true, -- Conceal whenever an item is marked as undone
				icon = "×"
			}
		},
		quote = {
			enabled = true, -- Conceal quotes
			icon = "∣"
		},
		heading = {
			enabled = true, -- Enable beautified headings

			-- Define icons for all the different heading levels
			level_1 = {
				enabled = true,
				icon = "◉",
			},

			level_2 = {
				enabled = true,
				icon = "○",
			},

			level_3 = {
				enabled = true,
				icon = "✿",
			},

			level_4 = {
				enabled = true,
				icon = "•",
			},
		},

		marker = {
			enabled = true, -- Enable the beautification of markers
			icon = "",
		},
	}

	You can also add your own custom conceals with their own custom icons, however this is a tad more complex.

	Note that those are probably the configuration options that you are *going* to use.
	There are a lot more configuration options per element than that, however.

	Here are the more advanced parameters you may be interested in:

	pattern - the pattern to match. If this pattern isn't matched then the conceal isn't applied.

	whitespace_index - this one is a bit funny to explain. Basically, this is the index of a capture from
	the "pattern" variable representing the leading whitespace. This whitespace is then used to calculate
	where to place the icon. If your pattern specifies only one capture, set this to 1

	highlight - the highlight to apply to the icon

	padding_before - the amount of padding (in the form of spaces) to apply before the icon

NOTE: When defining your own icons be sure to set *all* the above variables plus the "icon" and "enabled" variables.
      If you don't you will get errors.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.concealer")

module.setup = function()
	return { success = true, requires = { "core.autocommands", "core.highlights" } }
end

module.private = {
	namespace = vim.api.nvim_create_namespace("neorg_conceals"),
	extmarks = {},
	icons = {}
}

module.config.public = {

	icons = {
		todo = {
			enabled = true,

			done = {
				enabled = true,
				icon = "",
				pattern = "^(%s*%-%s+%[%s*)x%s*%]%s+",
				whitespace_index = 1,
				highlight = "NeorgTodoItemDoneMark",
				padding_before = 0,
			},

			pending = {
				enabled = true,
				icon = "",
				pattern = "^(%s*%-%s+%[%s*)%*%s*%]%s+",
				whitespace_index = 1,
				highlight = "NeorgTodoItemPendingMark",
				padding_before = 0,
			},

			undone = {
				enabled = true,
				icon = "×",
				pattern = "^(%s*%-%s+%[)%s+]%s+",
				whitespace_index = 1,
				highlight = "TSComment",
				padding_before = 0,
			}
		},

		quote = {
			enabled = true,
			icon = "∣",
			pattern = "^(%s*)>%s+",
			whitespace_index = 1,
			highlight = "NeorgQuote",
			padding_before = 0,
		},

		heading = {
			enabled = true,

			level_1 = {
				enabled = true,
				icon = "◉",
				pattern = "^(%s*)%*%s+",
				whitespace_index = 1,
				highlight = "NeorgHeading1",
				padding_before = 0,
			},

			level_2 = {
				enabled = true,
				icon = "○",
				pattern = "^(%s*)%*%*%s+",
				whitespace_index = 1,
				highlight = "NeorgHeading2",
				padding_before = 1,
			},

			level_3 = {
				enabled = true,
				icon = "✿",
				pattern = "^(%s*)%*%*%*%s+",
				whitespace_index = 1,
				highlight = "NeorgHeading3",
				padding_before = 2,
			},

			level_4 = {
				enabled = true,
				icon = "•",
				pattern = "^(%s*)%*%*%*%*%s+",
				whitespace_index = 1,
				highlight = "NeorgHeading4",
				padding_before = 3,
			},
		},

		marker = {
			enabled = true,
			icon = "",
			pattern = "^(%s*)%|%s+",
			whitespace_index = 1,
			highlight = "NeorgMarker",
			padding_before = 0,
		},
	},

}

module.load = function()
	local get_enabled_icons

	-- @Summary Returns all the enabled icons from a table
	-- @Param  tbl (table) - the table to parse
	get_enabled_icons = function(tbl)
		-- Create a result that we will return at the end of the function
		local result = {}

		-- If the current table isn't enabled then don't parser any further - simply return the empty result
		if vim.tbl_isempty(tbl) or (tbl.enabled ~= nil and tbl.enabled == false) then
			return result
		end

		-- Go through every icon
		for name, icons in pairs(tbl) do
			-- If we're dealing with a table (which we should be) and if the current icon set is enabled then
			if type(icons) == "table" and icons.enabled then
				-- If we have defined an icon value then add that icon to the result
				if icons.icon then
					result[name] = icons
				else
					-- If we don't have an icon variable then we need to descend further down the lua table.
					-- To do this we recursively call this very function and merge the results into the result table
					result = vim.tbl_deep_extend("force", result, get_enabled_icons(icons))
				end
			end
		end

		return result
	end

	-- Set the module.private.icons variable to the values of the enabled icons
	module.private.icons = vim.tbl_values(get_enabled_icons(module.config.public.icons))

	-- Enable the required autocommands (these will be used to determine when to update conceals in the buffer)
	module.required["core.autocommands"].enable_autocommand("BufEnter")

	module.required["core.autocommands"].enable_autocommand("TextChanged")
	module.required["core.autocommands"].enable_autocommand("TextChangedI")

	-- Trigger the conceals
	module.public.trigger_conceal()
end

module.public = {

	-- @Summary Activates concealing for the current window
	-- @Description Parses the user configuration and enables concealing for the current window.
	trigger_conceal = function()
		-- Clear all the conceals beforehand (so no overlaps occur)
		module.public.clear_conceal()

		-- Go through every line in the file and attempt to apply a conceal to it
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)

		for i, line in ipairs(lines) do
			module.public.set_conceal(i, line)
		end
	end,

	-- @Summary Update conceals for the current line
	-- @Description Clears all conceals on the current line and reapplies them
	update_current_line = function()
		-- Get the current line number
		local line_number = vim.api.nvim_win_get_cursor(0)[1]

		-- Clear all conceals for the current line
		vim.api.nvim_buf_clear_namespace(0, module.private.namespace, line_number - 1, line_number)

		-- Reapply the conceals for the current line
		module.public.set_conceal(line_number, vim.api.nvim_get_current_line())
	end,

	-- @Summary Sets a conceal for the specified line
	-- @Description Attempts to match the current line to any valid conceal and tries applying it
	-- @Param  line_number (number) - the line number to conceal
	-- @Param  line (string) - the content of the line at the specified line number
	set_conceal = function(line_number, line)

		-- Loop through every enabled icon
		for _, icon_info in ipairs(module.private.icons) do
			-- If the icon has a pattern then attempt to match it
			if icon_info.pattern then
				-- Match the current line with the provided pattern
				local match = { line:match(icon_info.pattern) }

				-- If we have a match then apply the extmark
				if not vim.tbl_isempty(match) then
					-- Grab the amount of preceding whitespace in the match
					local whitespace_amount = match[icon_info.whitespace_index]:len()
					-- Construct the virtual text with any potential padding
					local full_icon = (" "):rep(icon_info.padding_before) .. icon_info.icon

					-- Actually set the extmark for the current line with all the required metadata
					module.public._set_extmark(full_icon, icon_info.highlight, line_number - 1, whitespace_amount, whitespace_amount + vim.api.nvim_strwidth(icon_info.icon))
				end
			end
		end
	end,

	-- @Summary Sets an extmark in the buffer
	-- @Description Mostly a wrapper around vim.api.nvim_buf_set_extmark in order to make it more safe
	-- @Param  text (string) - the virtual text to overlay (usually the icon)
	-- @Param  highlight (string) - the name of a highlight to use for the icon
	-- @Param  line_number (number) - the line number to apply the extmark in
	-- @Param  start_column (number) - the start column of the conceal
	-- @Param  end_column (number) - the end column of the conceal
	_set_extmark = function(text, highlight, line_number, start_column, end_column)

		-- Attempt to call vim.api.nvim_buf_set_extmark with all the parameters
 		local ok, result = pcall(vim.api.nvim_buf_set_extmark, 0, module.private.namespace, line_number, start_column,
 		{
    		end_col = end_column,
    		hl_group = highlight,
    		virt_text = { { text, highlight } },
    		virt_text_pos = "overlay",
    		hl_mode = "combine",
  		})

		-- If we have encountered an error then log it
  		if not ok then
    		log.error("Unable to create custom conceal for highlight:", highlight, "-", result)
  		end
	end,

	-- @Summary Clears all the conceals that neorg has defined
	-- @Description Simply clears the Neorg extmark namespace
	clear_conceal = function()
		vim.api.nvim_buf_clear_namespace(0, module.private.namespace, 0, -1)
	end

}

module.on_event = function(event)
	-- If we have just entered a .norg buffer then apply all conceals
	if event.type == "core.autocommands.events.bufenter" and event.content.norg then
		module.public.trigger_conceal()
	-- If the content of a line has changed then reparse that line
	elseif event.type == "core.autocommands.events.textchanged" or event.type == "core.autocommands.events.textchangedi" then
		module.public.update_current_line()
	end
end

module.events.subscribed = {

	["core.autocommands"] = {
		bufenter = true,
		textchangedi = true,
		textchanged = true
	}

}

return module
