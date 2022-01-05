local module = neorg.modules.extend("core.norg.concealer.preset_varied", "core.norg.concealer")

module.config.private.icon_preset_varied = {
    heading = {
        enabled = true,

        level_1 = {
            icon = "◉",
        },

        level_2 = {
            icon = " ◆",
        },

        level_3 = {
            icon = "  ✿",
        },

        level_4 = {
            icon = "   ○",
        },

        level_5 = {
            icon = "    ▶",
        },

        level_6 = {
            icon = "     ⤷",
        },
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
