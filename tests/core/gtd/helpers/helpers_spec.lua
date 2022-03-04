---@diagnostic disable: undefined-global
require("tests.config")

-- Import module
local helpers = neorg.modules.get_module("core.gtd.helpers")

describe("CORE.GTD.HELPERS", function()
    it("get_gtd_excluded_files returns the correct files", function()
        local expected = { "test_file_2.norg" }

        local actual = helpers.get_gtd_excluded_files()

        assert.same(expected, actual)
    end)
    it("get_gtd_files returns the correct files", function()
        local expected = { "inbox.norg", "index.norg", "test_file.norg" }

        local actual = helpers.get_gtd_files()

        assert.same(expected, actual)
    end)
    it("get_gtd_files returns the correct files with no_exclude set", function()
        local expected = { "inbox.norg", "index.norg", "test_file.norg", "test_file_2.norg" }

        local actual = helpers.get_gtd_files({ no_exclude = true })

        assert.same(expected, actual)
    end)
    describe("state_to_text", function()
        it("done", function()
            local expected = "- [x]"
            local input = "done"

            local actual = helpers.state_to_text(input)

            assert.equal(expected, actual)
        end)
        it("undone", function()
            local expected = "- [ ]"
            local input = "undone"

            local actual = helpers.state_to_text(input)

            assert.equal(expected, actual)
        end)
        it("pending", function()
            local expected = "- [-]"
            local input = "pending"

            local actual = helpers.state_to_text(input)

            assert.equal(expected, actual)
        end)
        it("uncertain", function()
            local expected = "- [?]"
            local input = "uncertain"

            local actual = helpers.state_to_text(input)

            assert.equal(expected, actual)
        end)
        it("urgent", function()
            local expected = "- [!]"
            local input = "urgent"

            local actual = helpers.state_to_text(input)

            assert.equal(expected, actual)
        end)
        it("recurring", function()
            local expected = "- [+]"
            local input = "recurring"

            local actual = helpers.state_to_text(input)

            assert.equal(expected, actual)
        end)
        it("onhold", function()
            local expected = "- [=]"
            local input = "onhold"

            local actual = helpers.state_to_text(input)

            assert.equal(expected, actual)
        end)
        it("cancelled", function()
            local expected = "- [_]"
            local input = "cancelled"

            local actual = helpers.state_to_text(input)

            assert.equal(expected, actual)
        end)
    end)
end)
