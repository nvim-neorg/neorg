require("neorg.modules.base")
require("neorg.modules")

local module = neorg.modules.create("core.norg.snippet")

module.config.public = {
    engine = "luasnip",
}

module.private = {
    engine = nil,
    engine_map = {},
}

module.private.engine_map.luasnip = "core.integrations.luasnip"

module.load = function()
    local module_path = module.private.engine_map[module.config.public.engine]
    if module_path and neorg.modules.load_module(module_path) then
        module.private.engine = neorg.modules.get_module(module_path)
    else
        log.error("Unable to load snippet module -", module.config.public.engine, "is not a recognized engine.")
        return
    end

    module.private.engine.get_snippets = function()
        return module.public.snippets
    end

    module.private.engine.create_snippets({
        snippets = module.config.public.snippets,
    })
end

module.public = {
    snippets = {
        {
            trigger = "cod",
            body = {
                "@code ",
                { insert = "language" },
                { newline = "  " },
                { cursor = {} },
                { newline = "@end" },
                { newline = "" },
                { ending = {} },
            },
            description = "Code block snippet for Neorg files",
        },
        {
            trigger = "img",
            body = {
                "@image ",
                { insert = "format" },
                { newline = "  " },
                { cursor = {} },
                { newline = "@end" },
                { newline = "" },
                { ending = {} },
            },
            description = "Image block snippet for Neorg files",
        },
    },
}

return module
