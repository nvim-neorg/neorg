---@diagnostic disable: undefined-global
require("tests.config")

-- Import module
local helpers = neorg.modules.get_module("core.gtd.helpers")

describe("CORE.GTD.HELPERS -", function()
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

    describe("is_processed", function()
        describe("task", function()
            it("returns false if no conditions are met", function()
                local data = { type = "task", inbox = true }
                local actual = helpers.is_processed(data)

                assert.equal(false, actual)
            end)
            it("task not in inbox returns true as time.due is a non empty table", function()
                local data = { type = "task", ["time.due"] = { "tomorrow" } }
                local actual = helpers.is_processed(data)
                helpers.is_processed(data)

                assert.equal(true, actual)
            end)
            it("task not in inbox returns true as waiting.for is a non empty table", function()
                local data = { type = "task", ["waiting.for"] = { "something" } }
                local actual = helpers.is_processed(data)
                helpers.is_processed(data)

                assert.equal(true, actual)
            end)
            it("task in inbox returns true as time.due is a non empty table", function()
                local data = { type = "task", ["time.due"] = { "tomorrow" }, inbox = true }
                local actual = helpers.is_processed(data)
                helpers.is_processed(data)

                assert.equal(true, actual)
            end)
            it("task not in inbox returns true as time.start is a non empty table", function()
                local data = { type = "task", ["time.start"] = { "tomorrow" }, inbox = true }
                local actual = helpers.is_processed(data)
                helpers.is_processed(data)

                assert.equal(true, actual)
            end)
        end)
        describe("project", function()
            it("returns nil if tasks is not passed in as an argument", function()
                local data = { type = "project" }
                local actual = helpers.is_processed(data)

                assert.equal(nil, actual)
            end)
            it("returns true if project is in someday", function()
                local data = { type = "project", contexts = { "someday" } }
                local actual = helpers.is_processed(data, { _ = "" })

                assert.equal(true, actual)
            end)
            it("returns false if someday and has unprocessed inbox", function()
                local data = { type = "project", contexts = { someday = "" }, inbox = {} }
                local actual = helpers.is_processed(data, { _ = "" })

                assert.equal(false, actual)
            end)
            it("returns false if empty projects are unprocessed", function()
                local data = { type = "project", uuid = 2, contexts = {} }
                local tasks = { { project_uuid = 1 } }
                local actual = helpers.is_processed(data, tasks)

                assert.equal(false, actual)
            end)
            it("returns true if project_tasks is empty", function()
                local data = { type = "project", uuid = 2, contexts = {} }
                local tasks = { { state = "not done", project_uuid = 2 }, { state = "done", project_uuid = 2 } }
                local actual = helpers.is_processed(data, tasks)

                assert.equal(true, actual)
            end)
            it("returns false if all tasks are proccessed", function()
                local data = { type = "project", uuid = 2, contexts = {} }
                local tasks = { { state = "done", project_uuid = 2 }, { state = "done", project_uuid = 2 } }
                local actual = helpers.is_processed(data, tasks)

                assert.equal(false, actual)
            end)
        end)
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
        it("on_hold", function()
            local expected = "- [=]"
            local input = "on_hold"

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
