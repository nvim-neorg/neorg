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
        vim.api.nvim_create_autocmd("BufEnter", {
            callback = function(ev)
                local is_norg = vim.bo.filetype == "norg"

                local preset = module.private.presets[module.config.public.preset]
                assert(preset, string.format("keybind preset `%s` does not exist!", module.config.public.preset))

                local function set_keys_for(data)
                    for mode, keybinds in pairs(data) do
                        for _, keybind in ipairs(keybinds) do
                            if vim.fn.hasmapto(keybind[2], mode, false) == 0 then
                                local opts = vim.tbl_deep_extend("force", { buffer = ev.buf }, keybinds.opts or {})
                                vim.keymap.set(mode, keybind[1], keybind[2], opts)
                            end
                        end
                    end
                end

                set_keys_for(preset.all)

                if is_norg then
                    set_keys_for(preset.norg)
                end
            end,
        })
    end
end

module.private = {
    presets = {
        neorg = {
            all = {
                n = {
                    -- Creates a new .norg file to take notes in
                    -- ^New Note
                    {
                        "<LocalLeader>nn",
                        "<Plug>(neorg.dirman.new-note)",
                        opts = { desc = "[neorg] Create New Note" },
                    },
                },
            },
            norg = {
                n = {
                    -- Marks the task under the cursor as "undone"
                    -- ^mark Task as Undone
                    {
                        "<LocalLeader>tu",
                        "<Plug>(neorg.qol.todo-items.todo.task-undone)",
                        opts = { desc = "[neorg] Mark as Undone" },
                    },

                    -- Marks the task under the cursor as "pending"
                    -- ^mark Task as Pending
                    {
                        "<LocalLeader>tp",
                        "<Plug>(neorg.qol.todo-items.todo.task-pending)",
                        opts = { desc = "[neorg] Mark as Pending" },
                    },

                    -- Marks the task under the cursor as "done"
                    -- ^mark Task as Done
                    {
                        "<LocalLeader>td",
                        "<Plug>(neorg.qol.todo-items.todo.task-done)",
                        opts = { desc = "[neorg] Mark as Done" },
                    },

                    -- Marks the task under the cursor as "on-hold"
                    -- ^mark Task as on Hold
                    {
                        "<LocalLeader>th",
                        "<Plug>(neorg.qol.todo-items.todo.task-on-hold)",
                        opts = { desc = "[neorg] Mark as On Hold" },
                    },

                    -- Marks the task under the cursor as "cancelled"
                    -- ^mark Task as Cancelled
                    {
                        "<LocalLeader>tc",
                        "<Plug>(neorg.qol.todo-items.todo.task-cancelled)",
                        opts = { desc = "[neorg] Mark as Cancelled" },
                    },

                    -- Marks the task under the cursor as "recurring"
                    -- ^mark Task as Recurring
                    {
                        "<LocalLeader>tr",
                        "<Plug>(neorg.qol.todo-items.todo.task-recurring)",
                        opts = { desc = "[neorg] Mark as Recurring" },
                    },

                    -- Marks the task under the cursor as "important"
                    -- ^mark Task as Important
                    {
                        "<LocalLeader>ti",
                        "<Plug>(neorg.qol.todo-items.todo.task-important)",
                        opts = { desc = "[neorg] Mark as Important" },
                    },

                    -- Marks the task under the cursor as "ambiguous"
                    -- ^mark Task as ambiguous
                    {
                        "<LocalLeader>ta",
                        "<Plug>(neorg.qol.todo-items.todo.task-ambiguous)",
                        opts = { desc = "[neorg] Mark as Ambigous" },
                    },

                    -- Switches the task under the cursor between a select few states
                    {
                        "<C-Space>",
                        "<Plug>(neorg.qol.todo-items.todo.task-cycle)",
                        opts = { desc = "[neorg] Cycle Task" },
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
                        "<Plug>(neorg.pivot.list.toggle)",
                        opts = { desc = "[neorg] Toggle (Un)ordered List" },
                    },
                    {
                        "<LocalLeader>li",
                        "<Plug>(neorg.pivot.list.invert)",
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
                    { ">", "<Plug>(neorg.promo.promote.range)", opts = { desc = "[neorg] Promote Objects in Range" } },
                    { "<", "<Plug>(neorg.promo.demote.range)", opts = { desc = "[neorg] Demote Objects in Range" } },
                },
            }
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
