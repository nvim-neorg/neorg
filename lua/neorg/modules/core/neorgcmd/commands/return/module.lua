--[[
    file: Neorgcmd-return
    title: Provides the `:Neorg return` Command
    summary: Return to last location before entering Neorg.
    internal: true
    ---
When executed (`:Neorg return`), all currently open `.norg` files are deleted from
the buffer list, and the current workspace is set to "default".
--]]

local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.neorgcmd.commands.return")

module.setup = function()
    return { success = true, requires = { "core.neorgcmd" } }
end

module.public = {
    neorg_commands = {
        ["return"] = {
            args = 0,
            name = "return",
        },
    },
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.return" then
        -- Get all the buffers
        local buffers = vim.api.nvim_list_bufs()

        local to_delete = {}
        for buffer in vim.iter(buffers):rev() do
            if vim.fn.buflisted(buffer) == 1 then
                -- If the listed buffer we're working with has a .norg extension then remove it (not forcibly)
                if not vim.endswith(vim.api.nvim_buf_get_name(buffer), ".norg") then
                    vim.api.nvim_win_set_buf(0, buffer)
                    break
                else
                    table.insert(to_delete, buffer)
                end
            end
        end

        for _, buffer in ipairs(to_delete) do
            vim.api.nvim_buf_delete(buffer, {})
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["return"] = true,
    },
}

return module
