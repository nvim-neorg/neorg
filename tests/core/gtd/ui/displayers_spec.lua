---@diagnostic disable: undefined-global
require("tests.config")

-- Get the required module
local ui = neorg.modules.get_module("core.gtd.ui")

describe("CORE.GTD.QUERIES - Displayers:", function()
    it("Displays today tasks", function()
        local tasks = {
            { content = "test_task", contexts = { "today", "mac" }, state = "undone" },
            { content = "done_task", contexts = { "today", "home" }, state = "done" },
            { content = "test_task2", contexts = { "today", "home" }, state = "undone" },
        }
        local buf = ui.display_today_tasks(tasks)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_true(vim.tbl_contains(lines, "** mac"))
        assert.is_true(vim.tbl_contains(lines, "** home"))

        assert.is_false(vim.tbl_contains(lines, "- done_task"))
        assert.is_true(vim.tbl_contains(lines, "- test_task"))
        assert.is_true(vim.tbl_contains(lines, "- test_task2"))

        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- test_task2"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- test_task"
        end, lines))

        vim.api.nvim_buf_delete(buf, {})
    end)

    it("Displays waiting for tasks", function()
        local tasks = {
            {
                content = "test_task",
                contexts = { "today", "mac" },
                state = "undone",
                ["waiting.for"] = { "danymat", "vhyrro" },
            },
            {
                content = "done_task",
                contexts = { "today", "home" },
                state = "done",
                ["waiting.for"] = { "danymat", "vhyrro" },
            },
            {
                content = "test_task2",
                contexts = { "today", "home" },
                state = "undone",
                ["waiting.for"] = { "vhyrro" },
            },
        }

        local buf = ui.display_waiting_for(tasks)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_true(vim.tbl_contains(lines, "** danymat"))
        assert.is_true(vim.tbl_contains(lines, "** vhyrro"))
        assert.is_true(vim.tbl_contains(lines, "- test_task"))
        assert.is_false(vim.tbl_contains(lines, "- done_task"))

        assert.equals(2, #vim.tbl_filter(function(t)
            return t == "- test_task"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- test_task2"
        end, lines))

        vim.api.nvim_buf_delete(buf, {})
    end)
end)
