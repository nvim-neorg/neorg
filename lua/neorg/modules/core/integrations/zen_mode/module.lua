local modules = require("neorg.modules")
local module = modules.create("core.integrations.zen_mode")

module.load = function()
    local success, zen_mode = pcall(require, "zen_mode")

    assert(success, "Unable to load zen_mode...")

    zen_mode.setup(module.config.public)

    module.private.zen_mode = zen_mode
end

module.private = {
    zen_mode = nil,
}

module.config.public = {
    -- zen_mode setup configs: https://github.com/folke/zen-mode.nvim
    setup = {},
}

---@class core.integrations.zen_mode
module.public = {
    toggle = function()
        vim.cmd(":ZenMode")
    end,
}
return module
