local module = neorg.modules.extend("core.norg.concealer.preset_dimmed", "core.norg.concealer")

module.config.private.markup_preset_dimmed = {
    enabled = true,

    bold = {
        enabled = false,
    },

    italic = {
        enabled = false,
    },

    underline = {
        enabled = false,
    },

    strikethrough = {
        enabled = false,
    },

    subscript = {
        enabled = false,
    },

    superscript = {
        enabled = false,
    },

    verbatim = {
        enabled = false,
    },

    comment = {
        enabled = false,
    },

    math = {
        enabled = false,
    },

    variable = {
        enabled = false,
    },

    spoiler = {
        -- remains unchanged
    },

    link_modifier = {
        enabled = false,
    },

    trailing_modifier = {
        enabled = false,
    },

    url = {
        enabled = false,
    },
}

return module
