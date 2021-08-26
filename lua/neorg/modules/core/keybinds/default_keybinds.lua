return function(neorg_leader)
    local neorg_callbacks = require("neorg.callbacks")

    neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybinds)
        -- Map all the below keybinds only when the "norg" mode is active
        keybinds.map_event_to_mode("norg", {
            n = { -- Bind keys in normal mode

                -- Keys for managing TODO items and setting their states
                { "gtd", "core.norg.qol.todo_items.todo.task_done" },
                { "gtu", "core.norg.qol.todo_items.todo.task_undone" },
                { "gtp", "core.norg.qol.todo_items.todo.task_pending" },
                { "<C-Space>", "core.norg.qol.todo_items.todo.task_cycle" },

                -- Keys for managing notes
                { neorg_leader .. "nn", "core.norg.dirman.new.note" },

                { "<CR>", "core.norg.esupports.goto_link" },

                { "<C-s>", "core.integrations.telescope.find_linkable" },
            },

            i = {
                { "<C-l>", "core.integrations.telescope.insert_link" },
            },
        }, {
            silent = true,
            noremap = true,
        })

        -- Map the below keys only when traverse-heading mode is active
        keybinds.map_event_to_mode("traverse-heading", {
            n = {
                -- Rebind j and k to move between headings in traverse-heading mode
                { "j", "core.integrations.treesitter.next.heading" },
                { "k", "core.integrations.treesitter.previous.heading" },
            },
        }, {
            silent = true,
            noremap = true,
        })

        -- Apply the below keys to all modes
        keybinds.map_to_mode("all", {
            n = {
                { neorg_leader .. "mn", ":Neorg set-mode norg<CR>" },
                { neorg_leader .. "mh", ":Neorg set-mode traverse-heading<CR>" },
            },
        }, {
            silent = true,
            noremap = true,
        })
    end)
end
