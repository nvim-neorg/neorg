local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.keybinds.keybinds")

---@class core.keybinds
module.config.public = {
    keybind_presets = {
        neorg = function(keybinds)
            local leader = keybinds.leader

            -- Map all the below keybinds only when the "norg" mode is active
            keybinds.map_event_to_mode("norg", {
                n = {
                    -- Marks the task under the cursor as "undone"
                    -- ^mark Task as Undone
                    {
                        leader .. "tu",
                        "core.qol.todo_items.todo.task_undone",
                        opts = { desc = "[neorg] Mark as Undone" },
                    },

                    -- Marks the task under the cursor as "pending"
                    -- ^mark Task as Pending
                    {
                        leader .. "tp",
                        "core.qol.todo_items.todo.task_pending",
                        opts = { desc = "[neorg] Mark as Pending" },
                    },

                    -- Marks the task under the cursor as "done"
                    -- ^mark Task as Done
                    { leader .. "td", "core.qol.todo_items.todo.task_done", opts = { desc = "[neorg] Mark as Done" } },

                    -- Marks the task under the cursor as "on_hold"
                    -- ^mark Task as on Hold
                    {
                        leader .. "th",
                        "core.qol.todo_items.todo.task_on_hold",
                        opts = { desc = "[neorg] Mark as On Hold" },
                    },

                    -- Marks the task under the cursor as "cancelled"
                    -- ^mark Task as Cancelled
                    {
                        leader .. "tc",
                        "core.qol.todo_items.todo.task_cancelled",
                        opts = { desc = "[neorg] Mark as Cancelled" },
                    },

                    -- Marks the task under the cursor as "recurring"
                    -- ^mark Task as Recurring
                    {
                        leader .. "tr",
                        "core.qol.todo_items.todo.task_recurring",
                        opts = { desc = "[neorg] Mark as Recurring" },
                    },

                    -- Marks the task under the cursor as "important"
                    -- ^mark Task as Important
                    {
                        leader .. "ti",
                        "core.qol.todo_items.todo.task_important",
                        opts = { desc = "[neorg] Mark as Important" },
                    },

                    -- Marks the task under the cursor as "ambiguous"
                    -- ^mark Task as ambiguous
                    {
                        leader .. "ta",
                        "core.qol.todo_items.todo.task_ambiguous",
                        opts = { desc = "[neorg] Mark as Ambigous" },
                    },

                    -- Switches the task under the cursor between a select few states
                    { "<C-Space>", "core.qol.todo_items.todo.task_cycle", opts = { desc = "[neorg] Cycle Task" } },

                    -- Creates a new .norg file to take notes in
                    -- ^New Note
                    { leader .. "nn", "core.dirman.new.note", opts = { desc = "[neorg] Create New Note" } },

                    -- Hop to the destination of the link under the cursor
                    { "<CR>", "core.esupports.hop.hop-link", opts = { desc = "[neorg] Jump to Link" } },
                    { "gd", "core.esupports.hop.hop-link", opts = { desc = "[neorg] Jump to Link" } },
                    { "gf", "core.esupports.hop.hop-link", opts = { desc = "[neorg] Jump to Link" } },
                    { "gF", "core.esupports.hop.hop-link", opts = { desc = "[neorg] Jump to Link" } },

                    -- Same as `<CR>`, except opens the destination in a vertical split
                    {
                        "<M-CR>",
                        "core.esupports.hop.hop-link",
                        "vsplit",
                        opts = { desc = "[neorg] Jump to Link (Vertical Split)" },
                    },

                    { ">.", "core.promo.promote", opts = { desc = "[neorg] Promote Object (Non-Recursively)" } },
                    { "<,", "core.promo.demote", opts = { desc = "[neorg] Demote Object (Non-Recursively)" } },

                    { ">>", "core.promo.promote", "nested", opts = { desc = "[neorg] Promote Object (Recursively)" } },
                    { "<<", "core.promo.demote", "nested", opts = { desc = "[neorg] Demote Object (Recursively)" } },

                    {
                        leader .. "lt",
                        "core.pivot.toggle-list-type",
                        opts = { desc = "[neorg] Toggle (Un)ordered List" },
                    },
                    {
                        leader .. "li",
                        "core.pivot.invert-list-type",
                        opts = { desc = "[neorg] Invert (Un)ordered List" },
                    },

                    { leader .. "id", "core.tempus.insert-date", opts = { desc = "[neorg] Insert Date" } },
                },

                i = {
                    { "<C-t>", "core.promo.promote", opts = { desc = "[neorg] Promote Object (Recursively)" } },
                    { "<C-d>", "core.promo.demote", opts = { desc = "[neorg] Demote Object (Recursively)" } },
                    { "<M-CR>", "core.itero.next-iteration", "<CR>", opts = { desc = "[neorg] Continue Object" } },
                    { "<M-d>", "core.tempus.insert-date-insert-mode", opts = { desc = "[neorg] Insert Date" } },
                },

                -- TODO: Readd these
                -- v = {
                --     { ">>", ":<cr><cmd>Neorg keybind all core.promo.promote_range<cr>" },
                --     { "<<", ":<cr><cmd>Neorg keybind all core.promo.demote_range<cr>" },
                -- },
            }, {
                silent = true,
                noremap = true,
            })

            -- Map the below keys only when traverse-heading mode is active
            keybinds.map_event_to_mode("traverse-heading", {
                n = {
                    -- Move to the next heading in the document
                    {
                        "j",
                        "core.integrations.treesitter.next.heading",
                        opts = { desc = "[neorg] Move to Next Heading" },
                    },

                    -- Move to the previous heading in the document
                    {
                        "k",
                        "core.integrations.treesitter.previous.heading",
                        opts = { desc = "[neorg] Move to Previous Heading" },
                    },
                },
            }, {
                silent = true,
                noremap = true,
            })

            -- Map the below keys only when traverse-link mode is active
            keybinds.map_event_to_mode("traverse-link", {
                n = {
                    -- Move to the next link in the document
                    { "j", "core.integrations.treesitter.next.link", opts = { desc = "[neorg] Move to Next Link" } },

                    -- Move to the previous link in the document
                    {
                        "k",
                        "core.integrations.treesitter.previous.link",
                        opts = { desc = "[neorg] Move to Previous Link" },
                    },
                },
            }, {
                silent = true,
                noremap = true,
            })

            -- Map the below keys on presenter mode
            keybinds.map_event_to_mode("presenter", {
                n = {
                    { "<CR>", "core.presenter.next_page", opts = { desc = "[neorg] Next Page" } },
                    { "l", "core.presenter.next_page", opts = { desc = "[neorg] Next Page" } },
                    { "h", "core.presenter.previous_page", opts = { desc = "[neorg] Previous Page" } },

                    -- Keys for closing the current display
                    { "q", "core.presenter.close", opts = { desc = "[neorg] Close Presentation" } },
                    { "<Esc>", "core.presenter.close", opts = { desc = "[neorg] Close Presentation" } },
                },
            }, {
                silent = true,
                noremap = true,
                nowait = true,
            })

            -- Apply the below keys to all modes
            keybinds.map_to_mode("all", {
                n = {
                    { leader .. "mn", "<cmd>Neorg mode norg<CR>", opts = { desc = "[neorg] Enter Norg Mode" } },
                    {
                        leader .. "mh",
                        "<cmd>Neorg mode traverse-heading<CR>",
                        opts = { desc = "[neorg] Enter Heading Traversal Mode" },
                    },
                    {
                        leader .. "ml",
                        "<cmd>Neorg mode traverse-link<CR>",
                        opts = { desc = "[neorg] Enter Link Traversal Mode" },
                    },
                    { "gO", "<cmd>Neorg toc split<CR>", opts = { desc = "[neorg] Open a Table of Contents" } },
                },
            }, {
                silent = true,
                noremap = true,
            })
        end,
    },
}

return module
