--[[
	Module for implementing todo lists.

    Available binds:
    - todo.task_done
    - todo.task_undone
    - todo.task_pending
    - todo.task_cycle

    TODO: get rid of the pattern matching stuff within the on_event() local functions once the scanner module is ready
    TODO: use sym.states withing the on_event() local funtions once global utility functions become a thing
    TODO: make events name processing like a domain name such as making:

		["core.norg.qol.todo_items.todo.task_done"] = true,
		["core.norg.qol.todo_items.todo.task_undone"] = true,
		["core.norg.qol.todo_items.todo.task_pending"] = true,
		["core.norg.qol.todo_items.todo.task_cycle"] = true

    The same as:

        ["core.norg.qol.todo_items.todo] = {
            [task_done"] = true
            [task_undone"] = true
            [task_pending"] = true
            [task_cycle"] = true
        }
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.qol.todo_items")

module.setup = function()
	return { success = true, requires = { "core.keybinds" } }
end

module.config.private = {
    sym = {
        states = {
            done = "x",
            undone = " ",
            pending = "*",
        },
        left_bracket = "[",
        right_bracket = "]",
    }
}

module.load = function()
    -- TODO: create a utility function that takes a module name and table of binds to clean this up
    module.required["core.keybinds"].register_callback("core.norg.qol.todo_items", "todo.task_done")
    module.required["core.keybinds"].register_callback("core.norg.qol.todo_items", "todo.task_undone")
    module.required["core.keybinds"].register_callback("core.norg.qol.todo_items", "todo.task_pending")
    module.required["core.keybinds"].register_callback("core.norg.qol.todo_items", "todo.task_cycle")
end

module.on_event = function(event)
    local sym = module.config.private.sym

	if event.split_type[1] == "core.keybinds" then

		local set_todo_item_state = function(state)
			local current_line = vim.api.nvim_get_current_line()
			local str, _ = current_line:gsub("^(%s*%-%s+%" .. sym.left_bracket .. "%s*)[x%*%s](%s*%"..sym.right_bracket.."%s+)", "%1" .. state .. "%2", 1)
			if current_line ~= str then vim.api.nvim_set_current_line(str) end
		end

		local get_todo_item_state = function()
			return vim.api.nvim_get_current_line():match("^%s*%-%s+%" .. sym.left_bracket .. "%s*([x%*%s])%s*%"..sym.right_bracket.."%s+")
		end

		local cycle_todo_item = function()
			local states = { " ", "*", "x" }
			local next_state = get_todo_item_state()

			if not next_state then return end

			for i, state in ipairs(states) do
				if next_state == state then
					if i == #states then
						i = 1
					else
						i = i + 1
					end

					next_state = states[i]

					break
				end
			end

            set_todo_item_state(next_state)
		end

		if event.split_type[2] == "core.norg.qol.todo_items.todo.task_done" then
			set_todo_item_state(sym.states.done)
		elseif event.split_type[2] == "core.norg.qol.todo_items.todo.task_undone" then
			set_todo_item_state(sym.states.undone)
		elseif event.split_type[2] == "core.norg.qol.todo_items.todo.task_pending" then
			set_todo_item_state(sym.states.pending)
		elseif event.split_type[2] == "core.norg.qol.todo_items.todo.task_cycle" then
			cycle_todo_item()
		end

	end
end

module.events.subscribed = {
	["core.keybinds"] = {
		["core.norg.qol.todo_items.todo.task_done"] = true,
		["core.norg.qol.todo_items.todo.task_undone"] = true,
		["core.norg.qol.todo_items.todo.task_pending"] = true,
		["core.norg.qol.todo_items.todo.task_cycle"] = true
	}
}

return module
