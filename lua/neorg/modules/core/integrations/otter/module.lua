--[[
    file: Otter
    title: LSP Features in Code Cells
    description: Integrates with otter.nvim to get LSP features directly in norg code cells.
    ---

From the otter README:

> Otter.nvim provides lsp features and a code completion source for code embedded in other documents.

This includes:
- auto completion
- diagnostics
- hover
- rename symbol
- go to definition
- go to references
- go to type definition
- range formatting (not document formatting)

## Setup
You need to install otter.nvim and make sure it's loaded before Neorg, you can configure it yourself
by reading [the Otter.nvim README](https://github.com/jmbuhr/otter.nvim). You do not need to
configure `handle_leading_whitespace`, neorg will do that for you.

If you want auto complete, make sure you add `"otter"` as a source to nvim-cmp:

```lua
sources = {
  -- ... other sources
  { name = "otter" },
  -- ... other sources
}
```

## Commands
- `:Neorg otter enable` - enable otter in the current buffer
- `:Neorg otter disable` - disable otter in the current buffer
--]]

local neorg = require("neorg.core")
local module = neorg.modules.create("core.integrations.otter")

module.setup = function()
    return {
        success = pcall(require, "otter"),
        requires = {
            "core.neorgcmd",
        },
    }
end

local otter
module.load = function()
    local ok
    ok, otter = pcall(require, "otter")
    assert(ok, "[Neorg] Failed to load otter.nvim")

    -- This will not interfere with other otter.nvim configuration
    otter.setup({ handle_leading_whitespace = true })

    if module.config.public.auto_start then
        local group = vim.api.nvim_create_augroup("neorg.integrations.otter", {})
        vim.api.nvim_create_autocmd({ "BufReadPost" }, {
            desc = "Activate Otter on Buf Enter",
            pattern = "*.norg",
            group = group,
            callback = function(_)
                module.public.activate()
            end,
        })
    end

    module.required["core.neorgcmd"].add_commands_from_table({
        otter = {
            args = 1,
            name = "otter",
            condition = "norg",
            subcommands = {
                enable = {
                    args = 0,
                    name = "otter.enable",
                },
                disable = {
                    args = 0,
                    name = "otter.disable",
                },
            },
        },
    })
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["otter.enable"] = true,
        ["otter.disable"] = true,
    },
}

module.on_event = function(event)
    if module.private[event.split_type[2]] then
        module.private[event.split_type[2]](event)
    end
end

module.config.public = {
    -- list of languages that otter will try to start a language server for.
    -- `nil` means all languages
    languages = nil,

    -- Automatically start Otter when a norg buffer is opened
    auto_start = true,

    completion = {
        -- enable/disable Otter autocomplete
        enabled = true,
    },

    diagnostics = {
        -- enable/disable Otter diagnostics
        enabled = true,
    },
}

module.private = {
    ["otter.enable"] = function(_)
        module.public.activate()
    end,
    ["otter.disable"] = function(_)
        module.public.deactivate()
    end,
}

module.public = {
    ---Activate otter in the current buffer, includes setting buffer keymaps
    activate = function()
        otter.activate(
            module.config.public.languages,
            module.config.public.completion.enabled,
            module.config.public.diagnostics.enabled,
            nil -- or a query...
        )
    end,

    ---Deactivate otter in the current buffer, including unsetting buffer keymaps
    deactivate = function()
        otter.deactivate(module.config.public.completion.enabled, module.config.public.diagnostics.enabled)
    end,
}

return module
