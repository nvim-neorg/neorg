--[[
    File: Neorgcmd-return
    Title: Provides `:Neorg return` command
    Summary: Return to last location before entering Neorg.
    Internal: true
    ---
Command module for core.neorgcmd designed to return to the last location the user was in before they entered Neorg
--]]

require("neorg.modules.base")
require("neorg.modules")

local module = neorg.modules.create("core.neorgcmd.commands.return")

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

        for _, buffer in ipairs(buffers) do
            if vim.fn.buflisted(buffer) == 1 then
                -- If the listed buffer we're working with has a .norg extension then remove it (not forcibly)
                if vim.endswith(vim.api.nvim_buf_get_name(buffer), ".norg") then
                    vim.api.nvim_buf_delete(buffer, {})
                end
            end
        end

        -- Set the dirman workspace to the one we had before we started the Neorg environment
        neorg.modules.get_module("core.norg.dirman").set_workspace("default")
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["return"] = true,
    },
}

return module
