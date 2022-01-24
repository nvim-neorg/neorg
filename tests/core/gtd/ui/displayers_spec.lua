---@diagnostic disable: undefined-global
require("tests.config")

-- Get the required module
--- @type core.gtd.ui
local ui = neorg.modules.get_module("core.gtd.ui")
local queries = neorg.modules.get_module("core.gtd.queries")
local queries_helper = neorg.modules.get_module("core.gtd.queries.helpers")

local t = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local function get_date_in_x_days(days)
    -- Create a table to store the number of days in each month
    local month_days = {
        31,
        28,
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    }

    local date = os.date("*t")
    date.day = date.day + days

    if date.day > month_days[date.month] then
        date.day = date.day - month_days[date.month]
        date.month = date.month + 1
        if date.month > 12 then
            date.month = date.month - 12
            date.year = date.year + 1
        end
    end

    return os.time(date)
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
        local tasks = queries.get("tasks")
        tasks = queries.add_metadata(tasks, "task")
        local projects = queries.get("projects")
        projects = queries.add_metadata(projects, "project")

        local buf = ui.display_projects(tasks, projects)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_true(vim.tbl_contains(lines, "* Project (1/3 done)"))

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

    it("Displays weekly summary", function()
        local tasks = {
            {
                content = "task1",
                contexts = { "home", "mac" },
                state = "undone",
            },
            {
                content = "task2",
                contexts = { "home", "mac", "today" },
                state = "undone",
            },
            {
                content = "task5",
                state = "undone",
                contexts = { "mac" },
                ["time.start"] = { os.date("%Y-%m-%d") },
            },
        }

        local buf = ui.display_weekly_summary(tasks)
        assert.is_number(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.is_true(vim.tbl_contains(lines, "- task2, `marked as today`"))
        assert.is_true(vim.tbl_contains(lines, "- task5, `starting today`"))

        vim.api.nvim_buf_delete(buf, {})
    end)
    it("Convert weekday with amount to date", function()
        local values = {
            ["Monday"] = 0,
            ["Tueday"] = 1,
            ["Wednesday"] = 2,
            ["Thursday"] = 3,
            ["Friday"] = 4,
            ["Saturday"] = 5,
            ["Sunday"] = 6,
        }
        assert.is_true(
            queries_helper.date_converter("2mon") == os.date("%Y-%m-%d", get_date_in_x_days(14 - values[os.date("%A")]))
        )
    end)
end)
