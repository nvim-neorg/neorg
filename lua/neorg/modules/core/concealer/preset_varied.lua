local module = neorg.modules.create("core.concealer.preset_varied")

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
