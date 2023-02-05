--[[
    file: Truezen-Integration
    title: A TrueZen integration for Neorg
    summary: Integrates the TrueZen module for use within Neorg.
    internal: true
    ---
This is a basic wrapper around truezen that allows one to toggle the atraxis mode programatically.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.truezen")

module.load = function()
    local success, truezen = pcall(require, "true-zen.main")

    if not success then
        return { success = false }
    end

    module.private.truezen = truezen
end

module.private = {
    truezen = nil,
}

---@class core.integrations.truezen
module.public = {
    toggle_ataraxis = function()
        vim.cmd(":TZAtaraxis")
    end,
}

return module
