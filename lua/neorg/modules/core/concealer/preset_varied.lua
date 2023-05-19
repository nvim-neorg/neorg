local module = neorg.modules.extend("core.concealer.preset_varied", "core.concealer")

module.config.private.icon_preset_varied = {
    heading = {
        icons = { "◉", "◆", "✿", "○", "▶", "⤷" },
    },

    footnote = {
        single = {
            icon = "",
        },
        multi_prefix = {
            icon = " ",
        },
        multi_suffix = {
            icon = " ",
        },
    },
}

return module
