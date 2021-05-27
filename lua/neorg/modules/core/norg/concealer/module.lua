--[[
	CONCEALER MODULE FOR NEORG.
	This module is supposed to enhance the neorg editing experience
	by abstracting away certain bits of text and concealing it into one easy-to-recognize
	icon. Icons can be easily changed and most elements can be disabled.

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
	},

	-- The value to set `concealcursor` to (see `:h concealcursor`)
	conceal_cursor = ""
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.concealer")

module.setup = function()
	return { success = true, requires = { "core.autocommands" } }
end

module.load = function()
	module.required["core.autocommands"].enable_autocommand("BufEnter")
	module.public.trigger_conceal()
end

module.config.public = {

	icons = {
		todo = {
			enabled = true,

			done = {
				enabled = true,
				icon = ""
			},
			pending = {
				enabled = true,
				icon = ""
			},
			undone = {
				enabled = true,
				icon = "×"
			}
		},
		quote = {
			enabled = true,
			icon = "∣"
		},
		heading = {
			enabled = true,

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
			enabled = false,
			icon = "‑"
		},
	},

	conceal_cursor = ""

}

module.public = {

	trigger_conceal = function()
		vim.schedule(function()

			-- @Summary Creates a new conceal
			-- @Description Constructs a new match with regex via :syntax match
			-- @Param  name (string) - the name of the match
			-- @Param  regex (string) - the regex to match against
			-- @Param  tbl (table) - the table that contains an `enabled` and `icon` variable
			local create_syntax_match = function(name, regex, tbl)
				if tbl.enabled then
					vim.cmd("syntax match " .. name .. " " .. regex .. " conceal oneline cchar=" .. tbl.icon)
				end
			end

			-- Enable concealing for the current buffer
			vim.cmd [[ setlocal conceallevel=2 ]]

			-- Set the concealcursor as requested
			vim.cmd("setlocal concealcursor=" .. module.config.public.conceal_cursor)

			-- Define syntax for all the concealable characters

			create_syntax_match("NeorgUnorderedList", [[ /\%\(^\s*\)\@<=\-\%\(\s\+\)\@=/ ]], module.config.public.icons.list)

			create_syntax_match("NeorgQuote", [[ /\%\(^\s*\)\@<=>\%\(\s\+\)\@=/ ]], module.config.public.icons.quote)

			if module.config.public.icons.heading.enabled then
				create_syntax_match("NeorgHeading1", [[ /\%\(^\s*\)\@<=\*\%\(\s\+\)\@=/ ]], module.config.public.icons.heading.level_1)
				create_syntax_match("NeorgHeading2", [[ /\%\(^\s*\)\@<=\*\*\%\(\s\+\)\@=/ ]], module.config.public.icons.heading.level_2)
				create_syntax_match("NeorgHeading3", [[ /\%\(^\s*\)\@<=\*\*\*\%\(\s\+\)\@=/ ]], module.config.public.icons.heading.level_3)
				create_syntax_match("NeorgHeading4", [[ /\%\(^\s*\)\@<=\*\*\*\*\%\(\s\+\)\@=/ ]], module.config.public.icons.heading.level_4)
			end

			if module.config.public.icons.todo.enabled then
				create_syntax_match("NeorgTaskDone", [[ /\%\(^\s*\-\s\+\)\@<=\[\s*x\s*\]\%\(\s\+\)\@=/ ]], module.config.public.icons.todo.done)
				create_syntax_match("NeorgTaskUndone", [[ /\%\(^\s*\-\s\+\)\@<=\[\s\+]\%\(\s\+\)\@=/ ]], module.config.public.icons.todo.undone)
				create_syntax_match("NeorgTaskPending", [[ /\%\(^\s*\-\s\+\)\@<=\[\s*\*\s*\]\%\(\s\+\)\@=/ ]], module.config.public.icons.todo.pending)
			end

		end)
	end

}

module.on_event = function(event)
	if event.type == "core.autocommands.events.bufenter" then
		module.public.trigger_conceal()
	end
end

module.events.subscribed = {

	["core.autocommands"] = {
		bufenter = true
	}

}

return module
