--[[
    file: User-Keybinds
    title: The Language of Neorg
    description: `core.keybinds` manages mappings for operations on or in `.norg` files.
    summary: Module for managing keybindings with Neorg mode support.
    ---
--]]

local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.keybinds")

module.load = function()
    if module.config.public.default_keybinds then
        local preset = module.private.presets[module.config.public.preset]
        assert(preset, string.format("keybind preset `%s` does not exist!", module.config.public.preset))

        for mode, keybinds in pairs(preset) do
            for _, keybind in ipairs(keybinds) do
                if vim.fn.hasmapto(keybind[2], mode, false) == 0 then
                    vim.keymap.set(mode, keybind[1], keybind[2], keybind.opts or {})
                end
            end
        end
    end
end

-- Temporary functions to act as wrappers
module.public = {
    register_keybind = function (...)
    end,
    register_keybinds = function (...)
    end
}

module.private = {
    presets = {
        neorg = {
            n = {
                -- Marks the task under the cursor as "undone"
                -- ^mark Task as Undone
                {
                    "<LocalLeader>tu",
                    "<Plug>(neorg.qol.todo_items.todo.task_undone)",
                    opts = { desc = "[neorg] Mark as Undone" },
                },

                -- Marks the task under the cursor as "pending"
                -- ^mark Task as Pending
                {
                    "<LocalLeader>tp",
                    "<Plug>(neorg.qol.todo_items.todo.task_pending)",
                    opts = { desc = "[neorg] Mark as Pending" },
                },

                -- Marks the task under the cursor as "done"
                -- ^mark Task as Done
                {
                    "<LocalLeader>td",
                    "<Plug>(neorg.qol.todo_items.todo.task_done)",
                    opts = { desc = "[neorg] Mark as Done" },
                },

                -- Marks the task under the cursor as "on_hold"
                -- ^mark Task as on Hold
                {
                    "<LocalLeader>th",
                    "<Plug>(neorg.qol.todo_items.todo.task_on_hold)",
                    opts = { desc = "[neorg] Mark as On Hold" },
                },

                -- Marks the task under the cursor as "cancelled"
                -- ^mark Task as Cancelled
                {
                    "<LocalLeader>tc",
                    "<Plug>(neorg.qol.todo_items.todo.task_cancelled)",
                    opts = { desc = "[neorg] Mark as Cancelled" },
                },

                -- Marks the task under the cursor as "recurring"
                -- ^mark Task as Recurring
                {
                    "<LocalLeader>tr",
                    "<Plug>(neorg.qol.todo_items.todo.task_recurring)",
                    opts = { desc = "[neorg] Mark as Recurring" },
                },

                -- Marks the task under the cursor as "important"
                -- ^mark Task as Important
                {
                    "<LocalLeader>ti",
                    "<Plug>(neorg.qol.todo_items.todo.task_important)",
                    opts = { desc = "[neorg] Mark as Important" },
                },

                -- Marks the task under the cursor as "ambiguous"
                -- ^mark Task as ambiguous
                {
                    "<LocalLeader>ta",
                    "<Plug>(neorg.qol.todo_items.todo.task_ambiguous)",
                    opts = { desc = "[neorg] Mark as Ambigous" },
                },

                -- Switches the task under the cursor between a select few states
                {
                    "<C-Space>",
                    "<Plug>(neorg.qol.todo_items.todo.task_cycle)",
                    opts = { desc = "[neorg] Cycle Task" },
                },

                -- Creates a new .norg file to take notes in
                -- ^New Note
                {
                    "<LocalLeader>nn",
                    "<Plug>(neorg.dirman.new.note)",
                    opts = { desc = "[neorg] Create New Note" },
                },

                -- Hop to the destination of the link under the cursor
                { "<CR>", "<Plug>(neorg.esupports.hop.hop-link)", opts = { desc = "[neorg] Jump to Link" } },
                -- TODO: Move these to the "vim" preset
                -- { "gd", "<Plug>(neorg.esupports.hop.hop-link)", opts = { desc = "[neorg] Jump to Link" } },
                -- { "gf", "<Plug>(neorg.esupports.hop.hop-link)", opts = { desc = "[neorg] Jump to Link" } },
                -- { "gF", "<Plug>(neorg.esupports.hop.hop-link)", opts = { desc = "[neorg] Jump to Link" } },

                -- Same as `<CR>`, except opens the destination in a vertical split
                {
                    "<M-CR>",
                    "<Plug>(neorg.esupports.hop.hop-link.vsplit)",
                    opts = { desc = "[neorg] Jump to Link (Vertical Split)" },
                },

                { ">.", "<Plug>(neorg.promo.promote)", opts = { desc = "[neorg] Promote Object (Non-Recursively)" } },
                { "<,", "<Plug>(neorg.promo.demote)", opts = { desc = "[neorg] Demote Object (Non-Recursively)" } },

                {
                    ">>",
                    "<Plug>(neorg.promo.promote.nested)",
                    opts = { desc = "[neorg] Promote Object (Recursively)" },
                },
                { "<<", "<Plug>(neorg.promo.demote.nested)", opts = { desc = "[neorg] Demote Object (Recursively)" } },

                {
                    "<LocalLeader>lt",
                    "<Plug>(neorg.pivot.toggle-list-type)",
                    opts = { desc = "[neorg] Toggle (Un)ordered List" },
                },
                {
                    "<LocalLeader>li",
                    "<Plug>(neorg.pivot.invert-list-type)",
                    opts = { desc = "[neorg] Invert (Un)ordered List" },
                },

                { "<LocalLeader>id", "<Plug>(neorg.tempus.insert-date)", opts = { desc = "[neorg] Insert Date" } },
            },

            i = {
                { "<C-t>", "<Plug>(neorg.promo.promote)", opts = { desc = "[neorg] Promote Object (Recursively)" } },
                { "<C-d>", "<Plug>(neorg.promo.demote)", opts = { desc = "[neorg] Demote Object (Recursively)" } },
                { "<M-CR>", "<Plug>(neorg.itero.next-iteration)", opts = { desc = "[neorg] Continue Object" } },
                { "<M-d>", "<Plug>(neorg.tempus.insert-date-insert-mode)", opts = { desc = "[neorg] Insert Date" } },
            },

            v = {
                { ">", "<Plug>(neorg.promo.promote_range)", opts = { desc = "[neorg] Promote Objects in Range" } },
                { "<", "<Plug>(neorg.promo.demote_range)", opts = { desc = "[neorg] Demote Objects in Range" } },
            },
        },
    },
}

module.config.public = {
    -- Whether to use the default keybinds provided [here](https://github.com/nvim-neorg/neorg/blob/main/lua/neorg/modules/core/keybinds/keybinds.lua).
    default_keybinds = true,

    -- Which keybind preset to use.
    -- TODO: Docs
    preset = "neorg",
}

return module
