--[[
	Module for implementing todo lists.

    Available binds:
    - todo.task_done
    - todo.task_undone
    - todo.task_pending
    - todo.task_cycle

    TODO: get rid of the pattern matching stuff within the on_event() local functions once the scanner module is ready
    TODO: use sym.states within the on_event() local funtions once global utility functions become a thing

    The same as:

        ["core.norg.qol.todo_items.todo"] = {
            ["task_done"] = true
            ["task_undone"] = true
            ["task_pending"] = true
            ["task_cycle"] = true
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
	module.required["core.keybinds"].register_keybinds(module.name, { "todo.task_done", "todo.task_undone", "todo.task_pending", "todo.task_cycle" })
end

module.on_event = function(event)
    local sym = module.config.private.sym

	if event.split_type[1] == "core.keybinds" then

		-- @Summary Sets the current todo item's state
		-- @Param  state (string) - a string of characters to replace the current todo state
		local set_todo_item_state = function(state)
			-- Grab the current line
			local current_line = event.line_content

			-- Before you die of a heart attack, the below regex is supposed to pattern match a todo item,
			-- for example one that looks like this: - [x] Example!
			local str, _ = current_line:gsub("^(%s*%-%s+%" .. sym.left_bracket .. "%s*)[x%*%s](%s*%"..sym.right_bracket.."%s+)", "%1" .. state .. "%2", 1)

			-- If the current line differs from what we already have then change it!
			if current_line ~= str then vim.api.nvim_buf_set_lines(0, event.cursor_position[1] - 1, event.cursor_position[1], true, { str }) end
		end

		-- @Summary Gets the current todo item's state
		-- @Description Pattern matches the current line to query the current todo item.
		local get_todo_item_state = function()
			return event.line_content:match("^%s*%-%s+%" .. sym.left_bracket .. "%s*([x%*%s])%s*%" .. sym.right_bracket .. "%s+")
		end

		-- @Summary Cycles todo items
		-- @Description Queries the todo item on the current line and cycles it between a predefined list of states
		local cycle_todo_item = function()
			-- Define that states and query the current state
			local states = { " ", "x", "*" }
			local next_state = get_todo_item_state()

			-- If the current state cannot be found (ie. the current line is not a valid todo item) then don't do anything
			if not next_state then return end

			-- Loop through all values and find the next element
			for i, state in ipairs(states) do
				-- If we have found the current element
				if next_state == state then
					-- Then either wrap around to the beginning of the table if we're reading too far into it
					if i == #states then
						i = 1
					else -- Or advance the i variable by one
						i = i + 1
					end

					-- Define the next todo item state and exit the loop, everything was successful
					next_state = states[i]
					break
				end
			end

			-- Actually set the item state
            set_todo_item_state(next_state)
		end

		-- Depending on the event received perform different todo actions
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
