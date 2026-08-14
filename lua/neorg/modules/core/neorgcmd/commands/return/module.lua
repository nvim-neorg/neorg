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
        local last_non_norg = nil

        local to_delete = {}
        for buffer in vim.iter(buffers):rev() do
            if vim.fn.buflisted(buffer) == 1 and vim.api.nvim_buf_is_valid(buffer) then
                -- If the listed buffer we're working with has a .norg extension then remove it (not forcibly)
                if vim.endswith(vim.api.nvim_buf_get_name(buffer), ".norg") then
                    table.insert(to_delete, buffer)
                elseif not last_non_norg then
                    last_non_norg = buffer
                end
            end
        end

        -- Determine a safe fallback buffer (alternate or last non-norg)
        local target = nil
        local alt = vim.fn.bufnr("#")

        if
            alt ~= -1
            and vim.api.nvim_buf_is_valid(alt)
            and vim.fn.buflisted(alt) == 1
            and not vim.endswith(vim.api.nvim_buf_get_name(alt), ".norg")
        then
            target = alt
        else
            target = last_non_norg
        end

        if target then
            vim.api.nvim_set_current_buf(target)
        else
            local new_buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_set_current_buf(new_buf)
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
