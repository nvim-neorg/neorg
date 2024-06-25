--[[
    file: Truezen-Integration
    title: A TrueZen integration for Neorg
    summary: Integrates the TrueZen module for use within Neorg.
    internal: true
    ---
This is a basic wrapper around truezen that allows one to toggle the atraxis mode programmatically.
--]]

local neorg = require("neorg.core")
local modules, log = neorg.modules, neorg.log

local module = modules.create("core.integrations.truezen")

module.setup = function()
    local success, truezen = pcall(require, "true-zen.main")
    local success, truezen = pcall(require, "true-zen")

    if not success then
        log.warn("Could not find module: `true-zen`. Please ensure you have true-zen installed.")

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
