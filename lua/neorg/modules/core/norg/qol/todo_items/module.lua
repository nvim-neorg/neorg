--[[
	Module for adding helper keybinds to todo items.
USAGE:
	After loading the module 3 keybinds will be activated:
		- `gtd` -> g t(ask) d(one), marks a task as done
		- `gtu` -> g t(ask) u(ndone), marks a task as undone
		- `gtp` -> g t(ask) p(ending), marks a task as pending

	These keybinds only work when within the norg mode, which is the mode that neorg launches in by default.
	These can be rebound, obviously. If you would like your keys to be bound under <Leader>, you can configure
	the module like so:

	require('neorg').setup {
		load = {
			["core.norg.qol.todo_items"] = {
				config = {
					norg = {
						["<Leader>td"] = {
							mode = "n",
							name = "todo.task_done", -- Make sure it has this name
							opts = { noremap = true, silent = true }
						}

						-- Available `name`s are `todo.task_done`, `todo.task_undone` and `todo.task_pending`
					}
				}
			}
		}
	}
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.qol.todo_items")

module.setup = function()
	return { success = true, requires = { "core.keybinds" } }
end

module.config.public = {
	keybinds = {
		["norg"] = {
			["gtd"] = {
				mode = "n",
				name = "todo.task_done",
				prefix = false,
				opts = { noremap = true, silent = true }
			},
			["gtu"] = {
				mode = "n",
				name = "todo.task_undone",
				prefix = false,
				opts = { noremap = true, silent = true }
			},
			["gtp"] = {
				mode = "n",
				name = "todo.task_pending",
				prefix = false,
				opts = { noremap = true, silent = true }
			}
		}
	}
}

module.on_event = function(event)

	if event.split_type[1] == "core.keybinds" then

		local change_todo_item = function(char)
			local current_line = vim.api.nvim_get_current_line()
			local str, _ = current_line:gsub("^(%s*%-%s+%[%s*)[x%*%s](%s*%]%s+)", "%1" .. char .. "%2", 1)

			if current_line ~= str then
				vim.api.nvim_set_current_line(str)
			end
		end

		if event.split_type[2] == "core.norg.qol.todo_items.todo.task_done" then
			change_todo_item("x")
		elseif event.split_type[2] == "core.norg.qol.todo_items.todo.task_undone" then
			change_todo_item(" ")
		elseif event.split_type[2] == "core.norg.qol.todo_items.todo.task_pending" then
			change_todo_item("*")
		end

	end

end

module.events.subscribed = {

	["core.keybinds"] = {
		["core.norg.qol.todo_items.todo.task_done"] = true,
		["core.norg.qol.todo_items.todo.task_undone"] = true,
		["core.norg.qol.todo_items.todo.task_pending"] = true
	}

}

return module
