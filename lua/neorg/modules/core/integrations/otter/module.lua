--[[
    file: Otter
    title: LSP Features in Code Cells
    description: Integrates with otter.nvim to show diagnostics, give LSP auto complete, just to def, etc. directly in norg buffers.
    ---

Otter.nvim is a plugin that gives you LSP features in embedded languages. The LSP features include:
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
by reading [the Otter.nvim README](https://github.com/jmbuhr/otter.nvim).

If you want auto complete, make sure you add `"otter"` as a source to nvim-cmp (detailed in the
otter README)
```

## Commands
- `:Neorg otter enable` - enable otter in the current buffer
- `:Neorg otter disable` - disable otter in the current buffer
--]]

local neorg = require("neorg.core")
local module = neorg.modules.create("core.integrations.image")

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

    if module.config.public.auto_start then
        local group = vim.api.nvim_create_augroup("neorg.integrations.otter", {})
        vim.api.nvim_create_autocmd({ "BufEnter" }, {
            desc = "Activate Otter on Buf Enter",
            pattern = "*.norg",
            group = group,
            callback = function(_)
                module.public.activate()
            end
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
    -- list of languages that otter will try to start a language server for. nil means all languages
    languages = nil,

    -- Automatically start Otter when a norg buffer is opened
    auto_start = true,

    -- mappings that are set on the buffer when otter is activated
    keys = {
        hover = "K",
        definition = "gd",
        type_definition = "gD",
        references = "gr",
        rename = "<leader>rn",
        format = "<leader>gf",
        document_symbols = "gs",
    },

    completion = {
        -- enable/disable autocomplete
        enabled = true,
    },

    diagnostics = {
        -- enable/disable diagnostics
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

        local b = vim.api.nvim_get_current_buf()
        for func, lhs in pairs(module.config.public.keys) do
            vim.api.nvim_buf_set_keymap(
                b,
                "n",
                lhs,
                (":lua require'otter'.ask_%s()<cr>"):format(func),
                { silent = true, noremap = true }
            )
        end
    end,

    ---Deactivate otter in the current buffer, including unsetting buffer keymaps
    deactivate = function()
        -- TODO: there is no current way to deactivate otter. I have an open issue for this here
        -- https://github.com/jmbuhr/otter.nvim/issues/94
        otter.deactivate(
            module.config.public.completion.enabled,
            module.config.public.diagnostics.enabled
        )
        local b = vim.api.nvim_get_current_buf()
        for _, lhs in pairs(module.config.public.keys) do
            vim.api.nvim_buf_del_keymap(b, "n", lhs)
        end
    end,
}

return module
