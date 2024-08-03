--[[
    file: User-Keybinds
    title: The Language of Neorg
    description: `core.keybinds` manages mappings for operations on or in `.norg` files.
    summary: Module for managing keybindings with Neorg mode support.
    ---
The `core.keybinds` module configures an out-of-the-box Neovim experience by providing a default
set of keys.

To disable default keybinds, see the next section. To remap the existing keys, see [here](https://github.com/nvim-neorg/neorg/wiki/User-Keybinds#remapping-keys).

To find common problems, consult the [FAQ](https://github.com/nvim-neorg/neorg/wiki/User-Keybinds#faq).

### Disabling Default Keybinds

By default when you load the `core.keybinds` module all keybinds will be enabled. If you would like to change this, be sure to set `default_keybinds` to `false`:
```lua
["core.keybinds"] = {
    config = {
        default_keybinds = false,
    },
}
```

### Remapping Keys

To understand how to effectively remap keys, one must understand how keybinds are set.
Neorg binds actions to various `<Plug>` mappings that look like so: `<Plug>(neorg...`.

To remap a key, simply map an action somewhere in your configuration:

```lua
vim.keymap.set("n", "my-key-here", "<Plug>(neorg.pivot.list.toggle)", {})
```

Neorg will recognize that the key has been bound by you and not bind its own key.

#### Binding Keys for Norg Files Only

This approach has a downside - all of Neorg's keybinds are set on a per-buffer basis
so that keybinds don't "overflow" into buffers you don't want them active in.

When you map a key using `vim.keymap.set`, you set a global key which is always active, even in non-norg
files. There are two ways to combat this:
- Create a file under `<your-configuration>/ftplugin/norg.lua`:
  ```lua
  vim.keymap.set("n", "my-key-here", "<Plug>(neorg.pivot.list.toggle)", { buffer = true })
  ```
- Create an autocommand using `vim.api.nvim_create_autocmd`:
  ```lua
  vim.api.nvim_create_autocmd("Filetype", {
      pattern = "norg",
      callback = function()
          vim.keymap.set("n", "my-key-here", "<Plug>(neorg.pivot.list.toggle)", { buffer = true })
      end,
  })
  ```

Notice that in both situations a `{ buffer = true }` was supplied to the function.
This way, your remapped keys will never interfere with other files.

### Discovering Keys

A comprehensive list of all keybinds can be found on [this page!](https://github.com/nvim-neorg/neorg/wiki/Default-Keybinds)

## FAQ

### Some (or all) keybinds do not work

Neorg refuses to bind keys when it knows they'll interfere with your configuration.
Run `:checkhealth neorg` to see a full list of what keys Neorg has considered "conflicted"
or "rebound".

If you see that *all* of your keybinds are in conflict, you're likely using a plugin that is mapping to your
local leader key. This is a known issue with older versions of `which-key.nvim`. Since version `3.0` of which-key the issue has been fixed - we
recommend updating to the latest version to resolve the errors.

--]]

local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.keybinds")

local bound_keys = {}

module.load = function()
    if module.config.public.default_keybinds then
        local preset = module.private.presets[module.config.public.preset]
        assert(preset, string.format("keybind preset `%s` does not exist!", module.config.public.preset))

        module.public.set_keys_for(false, preset.all)

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "norg",
            callback = function(ev)
                module.public.set_keys_for(ev.buf, preset.norg)
            end,
        })
    end
end

module.config.public = {
    -- Whether to enable the default keybinds.
    default_keybinds = true,

    -- Which keybind preset to use.
    -- Currently allows only a single value: `"neorg"`.
    preset = "neorg",
}

---@class core.keybinds
module.public = {
    --- Adds a set of default keys for Neorg to bind.
    --- Should be used exclusively by external modules wanting to provide their own default keymaps.
    ---@param name string The name of the preset to extend (allows for providing default keymaps for various presets)
    ---@param preset neorg.keybinds.preset The preset data itself.
    extend_preset = function(name, preset)
        local original_preset = assert(module.private.presets[name], "provided preset doesn't exist!")

        local function extend(a, b)
            for k, v in pairs(b) do
                if type(v) == "table" then
                    if vim.islist(v) then
                        vim.list_extend(a[k], v)
                    else
                        extend(a[k], v)
                    end
                end

                a[k] = v
            end
        end

        extend(original_preset, preset)
        module.public.bind_norg_keys(vim.api.nvim_get_current_buf())
    end,

    ---@param buffer number|boolean
    ---@param preset_subdata table
    set_keys_for = function(buffer, preset_subdata)
        for mode, keybinds in pairs(preset_subdata) do
            bound_keys[mode] = bound_keys[mode] or {}

            for _, keybind in ipairs(keybinds) do
                if
                    vim.fn.hasmapto(keybind[2], mode, false) == 0
                    and vim.fn.mapcheck(keybind[1], mode, false):len() == 0
                then
                    local opts = vim.tbl_deep_extend("force", { buffer = buffer }, keybind.opts or {})
                    vim.keymap.set(mode, keybind[1], keybind[2], opts)

                    bound_keys[mode][keybind[1]] = true
                end
            end
        end
    end,

    --- Checks the health of keybinds. Returns all remaps and all conflicts in a table.
    ---@return { preset_exists: boolean, remaps: table<string, string>, conflicts: table<string, string> }
    health = function()
        local preset = module.private.presets[module.config.public.preset]

        if not preset then
            return {
                preset_exists = false,
            }
        end

        local remaps = {}
        local conflicts = {}

        local function check_keys_for(data)
            for mode, keybinds in pairs(data) do
                for _, keybind in ipairs(keybinds) do
                    if not bound_keys[mode] or not bound_keys[mode][keybind[1]] then
                        if vim.fn.hasmapto(keybind[2], mode, false) ~= 0 then
                            remaps[keybind[1]] = keybind[2]
                        elseif vim.fn.mapcheck(keybind[1], mode, false):len() ~= 0 then
                            conflicts[keybind[1]] = keybind[2]
                        end
                    end
                end
            end
        end

        check_keys_for(preset.all)
        check_keys_for(preset.norg)

        return {
            preset_exists = true,
            remaps = remaps,
            conflicts = conflicts,
        }
    end,
}

module.private = {

    -- TODO: Move these to the "vim" preset
    -- { "gd", "<Plug>(neorg.esupports.hop.hop-link)", opts = { desc = "[neorg] Jump to Link" } },
    -- { "gf", "<Plug>(neorg.esupports.hop.hop-link)", opts = { desc = "[neorg] Jump to Link" } },
    -- { "gF", "<Plug>(neorg.esupports.hop.hop-link)", opts = { desc = "[neorg] Jump to Link" } },
    presets = {
        ---@class neorg.keybinds.preset
        neorg = {
            all = {
                n = {
                    -- Create a new `.norg` file to take notes in
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
                    -- Mark the task under the cursor as "undone"
                    -- ^mark Task as Undone
                    {
                        "<LocalLeader>tu",
                        "<Plug>(neorg.qol.todo-items.todo.task-undone)",
                        opts = { desc = "[neorg] Mark as Undone" },
                    },

                    -- Mark the task under the cursor as "pending"
                    -- ^mark Task as Pending
                    {
                        "<LocalLeader>tp",
                        "<Plug>(neorg.qol.todo-items.todo.task-pending)",
                        opts = { desc = "[neorg] Mark as Pending" },
                    },

                    -- Mark the task under the cursor as "done"
                    -- ^mark Task as Done
                    {
                        "<LocalLeader>td",
                        "<Plug>(neorg.qol.todo-items.todo.task-done)",
                        opts = { desc = "[neorg] Mark as Done" },
                    },

                    -- Mark the task under the cursor as "on-hold"
                    -- ^mark Task as on Hold
                    {
                        "<LocalLeader>th",
                        "<Plug>(neorg.qol.todo-items.todo.task-on-hold)",
                        opts = { desc = "[neorg] Mark as On Hold" },
                    },

                    -- Mark the task under the cursor as "cancelled"
                    -- ^mark Task as Cancelled
                    {
                        "<LocalLeader>tc",
                        "<Plug>(neorg.qol.todo-items.todo.task-cancelled)",
                        opts = { desc = "[neorg] Mark as Cancelled" },
                    },

                    -- Mark the task under the cursor as "recurring"
                    -- ^mark Task as Recurring
                    {
                        "<LocalLeader>tr",
                        "<Plug>(neorg.qol.todo-items.todo.task-recurring)",
                        opts = { desc = "[neorg] Mark as Recurring" },
                    },

                    -- Mark the task under the cursor as "important"
                    -- ^mark Task as Important
                    {
                        "<LocalLeader>ti",
                        "<Plug>(neorg.qol.todo-items.todo.task-important)",
                        opts = { desc = "[neorg] Mark as Important" },
                    },

                    -- Mark the task under the cursor as "ambiguous"
                    -- ^mark Task as Ambiguous
                    {
                        "<LocalLeader>ta",
                        "<Plug>(neorg.qol.todo-items.todo.task-ambiguous)",
                        opts = { desc = "[neorg] Mark as Ambigous" },
                    },

                    -- Switch the task under the cursor between a select few states
                    {
                        "<C-Space>",
                        "<Plug>(neorg.qol.todo-items.todo.task-cycle)",
                        opts = { desc = "[neorg] Cycle Task" },
                    },

                    -- Hop to the destination of the link under the cursor
                    { "<CR>", "<Plug>(neorg.esupports.hop.hop-link)", opts = { desc = "[neorg] Jump to Link" } },

                    -- Same as `<CR>`, except open the destination in a vertical split
                    {
                        "<M-CR>",
                        "<Plug>(neorg.esupports.hop.hop-link.vsplit)",
                        opts = { desc = "[neorg] Jump to Link (Vertical Split)" },
                    },

                    -- Promote an object non-recursively
                    {
                        ">.",
                        "<Plug>(neorg.promo.promote)",
                        opts = { desc = "[neorg] Promote Object (Non-Recursively)" },
                    },
                    -- Demote an object non-recursively
                    { "<,", "<Plug>(neorg.promo.demote)", opts = { desc = "[neorg] Demote Object (Non-Recursively)" } },

                    -- Promote an object recursively
                    {
                        ">>",
                        "<Plug>(neorg.promo.promote.nested)",
                        opts = { desc = "[neorg] Promote Object (Recursively)" },
                    },
                    -- Demote an object recursively
                    {
                        "<<",
                        "<Plug>(neorg.promo.demote.nested)",
                        opts = { desc = "[neorg] Demote Object (Recursively)" },
                    },

                    -- Toggle a list from ordered <-> unordered
                    -- ^List Toggle
                    {
                        "<LocalLeader>lt",
                        "<Plug>(neorg.pivot.list.toggle)",
                        opts = { desc = "[neorg] Toggle (Un)ordered List" },
                    },

                    -- Invert all items in a list
                    -- Unlike `<LocalLeader>lt`, inverting a list will respect mixed list
                    -- items, instead of snapping all list types to a single one.
                    -- ^List Invert
                    {
                        "<LocalLeader>li",
                        "<Plug>(neorg.pivot.list.invert)",
                        opts = { desc = "[neorg] Invert (Un)ordered List" },
                    },

                    -- Insert a link to a date at the given position
                    -- ^Insert Date
                    { "<LocalLeader>id", "<Plug>(neorg.tempus.insert-date)", opts = { desc = "[neorg] Insert Date" } },

                    -- Magnifies a code block to a separate buffer.
                    -- ^Code Magnify
                    {
                        "<LocalLeader>cm",
                        "<Plug>(neorg.looking-glass.magnify-code-block)",
                        opts = { desc = "[neorg] Magnify Code Block" },
                    },
                },

                i = {
                    -- Promote an object recursively
                    {
                        "<C-t>",
                        "<Plug>(neorg.promo.promote)",
                        opts = { desc = "[neorg] Promote Object (Recursively)" },
                    },

                    -- Demote an object recursively
                    { "<C-d>", "<Plug>(neorg.promo.demote)", opts = { desc = "[neorg] Demote Object (Recursively)" } },

                    -- Create an iteration of e.g. a list item
                    { "<M-CR>", "<Plug>(neorg.itero.next-iteration)", opts = { desc = "[neorg] Continue Object" } },

                    -- Insert a link to a date at the current cursor position
                    -- ^Date
                    {
                        "<M-d>",
                        "<Plug>(neorg.tempus.insert-date.insert-mode)",
                        opts = { desc = "[neorg] Insert Date" },
                    },
                },

                v = {
                    -- Promote objects in range
                    { ">", "<Plug>(neorg.promo.promote.range)", opts = { desc = "[neorg] Promote Objects in Range" } },
                    -- Demote objects in range
                    { "<", "<Plug>(neorg.promo.demote.range)", opts = { desc = "[neorg] Demote Objects in Range" } },
                },
            },
        },
    },
}

return module
