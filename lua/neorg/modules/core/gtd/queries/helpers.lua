local module = neorg.modules.extend("core.gtd.queries.helpers")

module.private = {
    --- Insert formatted `content` in `t`, with `prefix` before it. Mutates `t` !
    --- @param t table
    --- @param content string|table
    --- @param prefix string
    insert_content = function(t, content, prefix)
        if not content then
            return
        end
        if type(content) == "string" then
            table.insert(t, prefix .. " " .. content)
        elseif type(content) == "table" then
            local inserted = prefix
            for _, v in pairs(content) do
                inserted = inserted .. " " .. v
            end
            table.insert(t, inserted)
        end
    end,
}

return module
