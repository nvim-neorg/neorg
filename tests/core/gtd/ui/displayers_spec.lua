---@diagnostic disable: undefined-global
require("tests.config")

-- Get the required module
local ui = neorg.modules.get_module("core.gtd.ui")

local t = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

describe("CORE.GTD.UI - Displayers:", function()
    it("Displays today tasks", function()
        local tasks = {
            { content = "test_task", contexts = { "today", "mac" }, state = "undone" },
            { content = "done_task", contexts = { "today", "home" }, state = "done" },
            { content = "test_task2", contexts = { "today", "home" }, state = "undone" },
            { content = "test_task3", contexts = { "today" }, state = "undone" },
        }
        local buf = ui.display_today_tasks(tasks)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_true(vim.tbl_contains(lines, "** mac"))
        assert.is_true(vim.tbl_contains(lines, "** home"))

        assert.is_false(vim.tbl_contains(lines, "- done_task"))
        assert.is_true(vim.tbl_contains(lines, "- test_task"))
        assert.is_true(vim.tbl_contains(lines, "- test_task2"))
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
            {
                content = "test_task3",
                contexts = { "today", "home" },
                state = "pending",
                ["waiting.for"] = { "vhyrro" },
            },
            {
                content = "test_task4",
                state = "undone",
                ["waiting.for"] = { "vhyrro" },
                ["time.start"] = { os.date("%Y-%m-%d") },
            },
            {
                content = "test_task5",
                state = "undone",
                ["waiting.for"] = { "vhyrro" },
                ["time.start"] = { "2100-01-01" },
            },
        }

        local buf = ui.display_waiting_for(tasks)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_true(vim.tbl_contains(lines, "** danymat"))
        assert.is_true(vim.tbl_contains(lines, "** vhyrro"))
        assert.is_false(vim.tbl_contains(lines, "- done_task"))
        assert.is_false(vim.tbl_contains(lines, "- test_task5"))

        assert.equals(2, #vim.tbl_filter(function(t)
            return t == "- test_task"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- test_task2"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- test_task3"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- test_task3"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- test_task4"
        end, lines))

        vim.api.nvim_buf_delete(buf, {})
    end)

    it("Displays contexts tasks", function()
        local tasks = {
            {
                content = "task1",
                contexts = { "home", "mac" },
                state = "undone",
            },
            {
                content = "task2",
                contexts = { "home", "mac" },
                state = "done",
            },
            {
                content = "task3",
                state = "undone",
            },
            {
                content = "task4",
                contexts = { "home" },
                state = "pending",
            },
            {
                content = "task5",
                state = "undone",
                contexts = { "mac" },
                ["time.start"] = { os.date("%Y-%m-%d") },
            },
            {
                content = "task6",
                state = "undone",
                contexts = { "mac" },
                ["time.start"] = { "2100-01-01" },
            },
        }

        local buf = ui.display_contexts(tasks)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_true(vim.tbl_contains(lines, "** home"))
        assert.is_true(vim.tbl_contains(lines, "** mac"))

        assert.is_false(vim.tbl_contains(lines, "- task2"))
        assert.is_false(vim.tbl_contains(lines, "- task6"))

        assert.equals(2, #vim.tbl_filter(function(t)
            return t == "- task1"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- task3"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- task4"
        end, lines))
        assert.equals(1, #vim.tbl_filter(function(t)
            return t == "- task5"
        end, lines))

        vim.api.nvim_buf_delete(buf, {})
    end)

    it("Displays projects", function()
        local tasks = {
            {
                content = "task1",
                contexts = { "home", "mac" },
                project = "project1",
                state = "undone",
            },
            {
                content = "task2",
                contexts = { "home", "mac" },
                project = "project2",
                state = "done",
            },
            {
                content = "task3",
                project = "project2",
                state = "undone",
            },
            {
                content = "task4",
                state = "undone",
            },
        }
        local projects = {
            {
                content = "project1",
                contexts = { "home" },
            },
            {
                content = "project2",
            },
        }

        local buf = ui.display_projects(tasks, projects)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_true(vim.tbl_contains(lines, "* project1 (0/1 done)"))
        assert.is_true(vim.tbl_contains(lines, "* project2 (1/2 done)"))
        assert.is_true(vim.tbl_contains(lines, "- /1 tasks don't have a project assigned/"))

        vim.api.nvim_buf_delete(buf, {})
    end)

    it("Displays someday tasks", function()
        local tasks = {
            {
                content = "task1",
                contexts = { "home", "mac" },
                state = "undone",
            },
            {
                content = "task2",
                contexts = { "home", "mac", "someday" },
                state = "done",
            },
            {
                content = "task3",
                state = "undone",
            },
            {
                content = "task4",
                contexts = { "home", "someday" },
                state = "pending",
            },
            {
                content = "task5",
                state = "undone",
                contexts = { "mac", "someday" },
                ["time.start"] = { os.date("%Y-%m-%d") },
            },
            {
                content = "task6",
                state = "undone",
                contexts = { "mac", "someday" },
                ["time.start"] = { "2100-01-01" },
            },
        }

        local buf = ui.display_someday(tasks)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_false(vim.tbl_contains(lines, "- task1 (`mac`)"))
        assert.is_false(vim.tbl_contains(lines, "- task2 (`home`, `mac`)"))
        assert.is_false(vim.tbl_contains(lines, "- task3"))
        assert.is_true(vim.tbl_contains(lines, "- task4 (`home`)"))
        assert.is_true(vim.tbl_contains(lines, "- task5 (`mac`)"))
        assert.is_true(vim.tbl_contains(lines, "- task6 (`mac`)"))

        vim.api.nvim_buf_delete(buf, {})
    end)
end)
