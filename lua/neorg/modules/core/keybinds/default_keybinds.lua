return function(neorg_leader)
	local neorg_callbacks = require('neorg.callbacks')

	neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, content)

		-- Keys for managing TODO items and setting their states
		content.map_event_to_mode("norg", {
			n = {
				{ "gtd", "core.norg.qol.todo_items.todo.task_done" },
				{ "gtu", "core.norg.qol.todo_items.todo.task_undone" },
				{ "gtp", "core.norg.qol.todo_items.todo.task_pending" },
				{ "<C-Space>", "core.norg.qol.todo_items.todo.task_cycle" },
				{ neorg_leader .. "nn", "core.norg.dirman.new.note" }
			}
		}, { silent = true, noremap = true })

		content.map_to_mode("norg", {
			n = {
				{ neorg_leader .. "mh", ":Neorg set-mode traverse-heading<CR>" }
			}
		}, { silent = true, noremap = true })

		content.map_to_mode("traverse-heading", {
			n = {
				{ "j", ":Neorg keybind traverse-heading core.integrations.treesitter.next.heading<CR>" },
				{ "k", ":Neorg keybind traverse-heading core.integrations.treesitter.previous.heading<CR>" },
				{ neorg_leader .. "mn", ":Neorg set-mode norg<CR>" }
			}
		}, { silent = true, noremap = true })

	end)
end
