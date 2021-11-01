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
end)
