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
        enabled = true,
        icon = ":",
        highlight = "NonText",
    },

    trailing_modifier = {
        enabled = true,
        icon = "~",
        highlight = "NonText",
    },

    url = {
        enabled = true,

        link = {
            enabled = true,

            unnamed = {
                enabled = true,
                highlight = "NonText",
                render = function(self, text)
                    return {
                        { text, self.highlight },
                    }
                end,
            },

            named = {
                enabled = true,

                location = {
                    enabled = true,
                    highlight = "NonText",
                    render = function(self, text)
                        return {
                            { text, self.highlight },
                        }
                    end,
                },

                text = {
                    enabled = true,
                    highlight = "NonText",
                    render = function(self, text)
                        return {
                            { text, self.highlight },
                        }
                    end,
                },
            },
        },

        anchor = {
            enabled = true,

            declaration = {
                enabled = true,
                highlight = "NonText",
                render = function(self, text)
                    return {
                        { text, self.highlight },
                    }
                end,
            },

            definition = {
                enabled = true,

                description = {
                    enabled = true,
                    highlight = "NonText",
                    render = function(self, text)
                        return {
                            { text, self.highlight },
                        }
                    end,
                },

                location = {
                    enabled = true,
                    highlight = "NonText",
                    render = function(self, text)
                        return {
                            { text, self.highlight },
                        }
                    end,
                },
            },
        },
    },
}

return module
