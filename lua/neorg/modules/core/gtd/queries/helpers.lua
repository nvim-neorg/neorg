neorg.modules.extend("core.gtd.queries.helpers")

module.public = {
    -- @Summary Convert a date from text to YY-MM-dd format
    -- @Description If the date is a quick capture (like 2w, 10d, 4m), it will convert to a standardized date
    -- Supported formats ($ treated as number):
    --   - $d: days from now (e.g 2d is 2 days from now)
    --   - $w: weeks from now (e.g 2w is 2 weeks from now)
    --   - $m: months from now (e.g 2m is 2 months from now)
    --   - tomorrow: tomorrow's date
    --   - today: today's date
    --   The format for date is YY-mm-dd
    -- @Param  text (string) the text to use
    date_converter = function(text)
        -- Get today's date
        local now = os.date("%Y-%m-%d")
        local y, m, d = now:match("(%d+)-(%d+)-(%d+)")

        -- Cases for converting quick dates to full dates (e.g 1w is one week from now)
        local converted_date
        local patterns = { weeks = "[%d]+w", days = "[%d]+d", months = "[%d]+m" }
        local days_matched = text:match(patterns.days)
        local weeks_matched = text:match(patterns.weeks)
        local months_matched = text:match(patterns.months)
        if text == "tomorrow" then
            converted_date = os.time({ year = y, month = m, day = d + 1 })
        elseif text == "today" then
            return now
        elseif weeks_matched ~= nil then
            converted_date = os.time({ year = y, month = m, day = d + 7 * weeks_matched:sub(1, -2) })
        elseif days_matched ~= nil then
            converted_date = os.time({ year = y, month = m, day = d + days_matched:sub(1, -2) })
        elseif months_matched ~= nil then
            converted_date = os.time({ year = y, month = m + months_matched:sub(1, -2), day = d })
        else
            return nil
        end
        return os.date("%Y-%m-%d", converted_date)
    end,
}

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
