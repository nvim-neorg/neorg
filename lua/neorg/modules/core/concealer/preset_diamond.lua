local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.concealer.preset_diamond")

module.config.private.icon_preset_diamond = {
    heading = {
        icons = { "◈", "◇", "◆", "⋄", "❖", "⟡" },
    },

    footnote = {
        single = {
            icon = "†",
        },
        multi_prefix = {
            icon = "‡ ",
        },
        multi_suffix = {
            icon = "‡ ",
        },
    },
}

return module
