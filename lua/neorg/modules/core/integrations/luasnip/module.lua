require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.luasnip")

module.private = {
    luasnip = {},
}

module.load = function()
    local success, luasnip = pcall(require, "luasnip")

    assert(success, "luasnip not found, aborting...")

    module.private.luasnip = luasnip
end

module.public = {
    create_snippets = function()
        local t = module.private.luasnip.t
        local s = module.private.luasnip.s
        local i = module.private.luasnip.i

        local snippets_base = module.public.get_snippets()
        local norg = {}
        local function make_snippet(body)
            local snip = {}
            local insertions = 1
            for _, part in ipairs(body) do
                local converted
                if type(part) == "string" then
                    converted = t(part)
                elseif type(part) == "table" then
                    if part.insert then
                        converted = i(insertions, part.insert)
                        insertions = insertions + 1
                    elseif part.cursor then
                        converted = i(insertions)
                        insertions = insertions + 1
                    elseif part.ending then
                        converted = i(0)
                    elseif part.newline then
                        if type(part.newline) == "string" then
                            converted = t({ "", part.newline })
                        else
                            converted = t({ "", "" })
                        end
                    end
                end

                snip[#snip + 1] = converted
            end

            return snip
        end

        for _, snippet in ipairs(snippets_base) do
            norg[#norg + 1] = s({
                trig = snippet.trigger,
                dscr = snippet.description,
            }, make_snippet(
                snippet.body
            ))
        end

        module.private.luasnip.snippets.norg = norg
    end,
}

return module
