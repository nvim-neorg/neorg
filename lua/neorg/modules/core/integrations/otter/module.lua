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
You need to install otter.nvim, and you can configure it yourself based on the Otter.nvim README.

Add this to your Neorg configuration:
```lua
["integrations.otter"] = {}, -- add your configuration here
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

    if module.public.config.auto_start then
        print("add some type of ftplugin or auto command")
    end

        module.required["core.neorgcmd"].add_commands_from_table({
        refactor = {
            min_args = 0,
            max_args = 1,
            name = "refactor",
            condition = "norg",
            subcommands = {
                rename = {
                    args = 1,
                    name = "refactor.rename",
                    subcommands = {
                        file = {
                            min_args = 0,
                            max_args = 1,
                            name = "refactor.rename.file",
                        },
                        heading = {
                            args = 0,
                            name = "refactor.rename.heading",
                        },
                    },
                },
            },
        },
    })

end

module.public.config = {
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
    status = false,
}

module.public = {
    ---Activate otter in the current buffer, includes setting buffer keymaps
    activate = function()
        otter.activate(
            module.public.config.languages,
            module.public.config.completion.enabled,
            module.public.config.diagnostics.enabled,
            nil -- or a query...
        )

        local b = vim.api.nvim_get_current_buf()
        for func, lhs in pairs(module.public.config.keys) do
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
        local b = vim.api.nvim_get_current_buf()
        for _, lhs in pairs(module.public.config.keys) do
            vim.api.nvim_buf_del_keymap(b, "n", lhs)
        end
    end,
}

return module
