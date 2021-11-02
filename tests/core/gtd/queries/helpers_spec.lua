---@diagnostic disable: undefined-global
require("tests.core.gtd.queries.config")

-- Get the required module
local queries = neorg.modules.get_module("core.gtd.queries")

describe("CORE.GTD.QUERIES - Helpers:", function()
    it("Converts a date", function()
        local date = queries.date_converter("2021-10-10")
        assert.equals("2021-10-10", date)

        date = queries.date_converter("today")
        assert.equals(os.date("%Y-%m-%d"), date)

        date = queries.date_converter("test_string")
        assert.is_nil(date)
        -- TODO: Add more test cases for custom dates
    end)

    it("Gets a diff between today's date", function()
        local date = os.date("*t")

        local time = os.time({ day = date.day + 3, year = date.year, month = date.month })
        local tested_date = os.date("%Y-%m-%d", time)
        local diff = queries.diff_with_today(tested_date)

        assert.is_table(diff)
        assert.equals(0, diff.weeks)
        assert.equals(3, diff.days)

        time = os.time({ day = date.day + 16, year = date.year, month = date.month })
        tested_date = os.date("%Y-%m-%d", time)
        diff = queries.diff_with_today(tested_date)

        assert.is_table(diff)
        assert.equals(2, diff.weeks)
        assert.equals(2, diff.days)

        diff = queries.diff_with_today("test_date")
        assert.is_nil(diff)
    end)
end)
