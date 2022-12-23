--[[
    file: ZenMode-Integration
    title: An integration for `zen-mode`
    summary: Integrates and exposes the functionality of `zen-mode` in Neorg.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.zen_mode")

module.load = function()
    local success, zen_mode = pcall(require, "zen_mode")

    if not success then
        return { success = false }
    end

    module.private.zen_mode = zen_mode
end

module.private = {
    zen_mode = nil,
}

---@class core.integrations.zen_mode
module.public = {
    toggle = function()
        vim.cmd(":ZenMode")
    end,
}
return module
