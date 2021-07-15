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
				icon = "⦿"
			},

			level_2 = {
				enabled = true,
				icon = "⦾"
			},

			level_3 = {
				enabled = true,
				icon = "•"
			},

			level_4 = {
				enabled = true,
				icon = "◦"
			},
		},
		list = {
			-- Option to conceal lists, disabled by default because for some it can look weird
			enabled = false,
			icon = "‑"
		},
	}

	You can also add your own custom conceals with their own custom icons, however this is a tad more complex.

	Note that those are probably the configuration options that you are *going* to use.
	There are a lot more configuration options per element than that, however.

	TODO: Complete docs
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
				force_length = 1,
				pattern = "^(%s*%-%s+%[%s*)x%s*%]%s+",
				whitespace_index = 1,
				highlight = "NeorgTodoItemDoneMark",
				padding_before = 0,
			},

			pending = {
				enabled = true,
				icon = "",
				force_length = 1,
				pattern = "^(%s*%-%s+%[%s*)%*%s*%]%s+",
				whitespace_index = 1,
				highlight = "NeorgTodoItemPendingMark",
				padding_before = 0,
			},

			undone = {
				enabled = true,
				icon = "×",
				force_length = 1,
				pattern = "^(%s*%-%s+%[)%s+]%s+",
				whitespace_index = 1,
				highlight = "TSComment",
				padding_before = 0,
			}
		},

		quote = {
			enabled = true,
			icon = "∣",
			force_length = 1,
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
				force_length = 1,
				pattern = "^(%s*)%*%s+",
				whitespace_index = 1,
				highlight = "NeorgHeading1",
				padding_before = 0,
			},

			level_2 = {
				enabled = true,
				icon = "○",
				force_length = 1,
				pattern = "^(%s*)%*%*%s+",
				whitespace_index = 1,
				highlight = "NeorgHeading2",
				padding_before = 1,
			},

			level_3 = {
				enabled = true,
				icon = "✿",
				force_length = 1,
				pattern = "^(%s*)%*%*%*%s+",
				whitespace_index = 1,
				highlight = "NeorgHeading3",
				padding_before = 2,
			},

			level_4 = {
				enabled = true,
				icon = "•",
				force_length = 1,
				pattern = "^(%s*)%*%*%*%*%s+",
				whitespace_index = 1,
				highlight = "NeorgHeading4",
				padding_before = 3,
			},
		},

		marker = {
			enabled = true,
			icon = "",
			force_length = 1,
			pattern = "^(%s*)%|%s+",
			whitespace_index = 1,
			highlight = "NeorgMarker",
			padding_before = 0,
		},
	},

}

module.load = function()
	local get_enabled_icons

	get_enabled_icons = function(tbl)
		local result = {}

		if tbl.enabled ~= nil and tbl.enabled == false then
			return result
		end

		for name, icons in pairs(tbl) do
			if type(icons) == "table" and icons.enabled then
				if icons.icon then
					result[name] = icons
				else
					result = vim.tbl_deep_extend("force", result, get_enabled_icons(icons))
				end
			end
		end

		return result
	end

	module.private.icons = vim.tbl_values(get_enabled_icons(module.config.public.icons))

	-- log.warn(module.private.icons)

	module.required["core.autocommands"].enable_autocommand("BufEnter")
	module.required["core.autocommands"].enable_autocommand("TextChanged")
	module.required["core.autocommands"].enable_autocommand("TextChangedI")

	module.public.trigger_conceal()
end

module.public = {

	-- @Summary Activates concealing for the current window
	-- @Description Parses the user configuration and enables concealing for the current window.
	trigger_conceal = function()
		module.public.clear_conceal()

		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

		for i, line in ipairs(lines) do
			module.public.set_extmark(i, line)
		end
	end,

	update_current_line = function()
		local line_number = vim.api.nvim_win_get_cursor(0)[1]

		vim.api.nvim_buf_clear_namespace(0, module.private.namespace, line_number - 1, line_number)

		module.public.set_extmark(line_number, vim.api.nvim_get_current_line())
	end,

	set_extmark = function(line_number, line)
		for _, icon_info in ipairs(module.private.icons) do
			if icon_info.pattern then
				local match = { line:match(icon_info.pattern) }

				if not vim.tbl_isempty(match) then
					local whitespace_amount = match[icon_info.whitespace_index]:len()
					local full_icon = (" "):rep(icon_info.padding_before) .. icon_info.icon
					local icon_length = (icon_info.force_length and icon_info.force_length or icon_info.icon:len())

					module.public._set_extmark(full_icon, icon_info.highlight, line_number - 1, whitespace_amount, whitespace_amount + icon_length)
				end
			end
		end
	end,

	_set_extmark = function(text, highlight, line_number, start_column, end_column)
 		local ok, result = pcall(vim.api.nvim_buf_set_extmark, 0, module.private.namespace, line_number, start_column,
 		{
    		end_col = end_column,
    		hl_group = highlight,
    		virt_text = { { text, highlight } },
    		virt_text_pos = "overlay",
    		hl_mode = "combine",
  		})

  		if not ok then
    		log.error("Unable to create custom conceal for highlight:", highlight, "-", result)
  		else
			-- module.private.extmarks[line_number] = module.private.extmarks[line_number] or {}
  		end
	end,

	-- @Summary Clears all the conceals that neorg has defined
	-- @Description Uses the `:syntax clear` command to remove all active conceals
	clear_conceal = function()
		vim.api.nvim_buf_clear_namespace(0, module.private.namespace, 0, -1)
	end

}

module.on_event = function(event)
	if event.type == "core.autocommands.events.bufenter" and event.content.norg then
		module.public.trigger_conceal()
	elseif event.type == "core.autocommands.events.textchanged" or event.type == "core.autocommands.events.textchangedi" then
		-- Just temporary
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
