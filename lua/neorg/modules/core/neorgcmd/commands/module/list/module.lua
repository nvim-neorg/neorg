--[[
    File: Neorgcmd-List
    Title: Provides `:Neorg list` command
    Summary: List loaded modules.
    Show: false.
    ---
After module is loaded execute `:Neorg module list` to see a primitive list of currently loaded modules.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.neorgcmd.commands.module.list")

module.setup = function()
    return { success = true, requires = { "core.neorgcmd" } }
end

module.public = {

    neorg_commands = {
        definitions = {
            module = {
                list = {},
            },
        },
        data = {
            module = {
                args = 1,

                subcommands = {

                    list = {
                        args = 0,
                        name = "module.list",
                    },
                },
            },
        },
    },
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.module.list" then
        local lines = { "--- Loaded Neorg Modules ---" }
        local ns = vim.api.nvim_create_namespace("neorg-module-list")

        for _, mod in pairs(neorg.modules.loaded_modules) do
            table.insert(lines, mod.name)
        end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>q<CR>", { noremap = true, silent = true, nowait = true })
        local width = vim.api.nvim_win_get_width(0)
        local height = vim.api.nvim_win_get_height(0)

        vim.api.nvim_open_win(buf, true, {
            relative = "win",
            win = 0,
            width = math.floor(width * 0.7),
            height = math.floor(height * 0.9),
            col = math.floor(width * 0.15),
            row = math.floor(height * 0.05),
            border = "single",
            style = "minimal",
        })

        vim.api.nvim_buf_add_highlight(buf, ns, "Special", 0, 4, 25)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["module.list"] = true,
    },
}

return module
