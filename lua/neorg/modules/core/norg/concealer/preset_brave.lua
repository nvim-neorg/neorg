local module = neorg.modules.extend("core.norg.concealer.preset_brave", "core.norg.concealer")

module.config.private.markup_preset_brave = {
    icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
    -- NOTE: if you're experiencing issues with this concealing, try using the
    -- safe preset instead.
}

return module
