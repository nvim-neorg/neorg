---@diagnostic disable: undefined-global

-- Generate a simple config file
local path = vim.fn.getcwd()
require("neorg").setup({
    load = {
        ["core.gtd.base"] = {
            config = {
                workspace = "gtd",
            },
        },
        ["core.norg.dirman"] = {
            config = {
                workspaces = {
                    gtd = path .. "/tests/core/gtd/queries",
                },
            },
        },
    },
})

-- Start neorg
neorg.org_file_entered(false)
neorg.modules.get_module("core.norg.dirman").set_workspace("gtd")

-- Get a test file bufnr
local workspace = neorg.modules.get_module("core.norg.dirman").get_workspace("gtd")
local filename = "test_file.norg"
local uri = vim.uri_from_fname(workspace .. "/" .. filename)
local buf = vim.uri_to_bufnr(uri)

local temp_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(temp_buf, "test.norg")
vim.api.nvim_buf_set_lines(temp_buf, 0, 0, false, {
    "* Project",
    "this is a test",
    "- [ ] test1",
    "- [ ] test2",
    "- [x] test3",
    "- [*] test4",
    "#contexts test_context test_context2",
    "#time.due 2021-10-10",
    "#time.start 2021-10-11",
    "#waiting.for test_waiting_for",
    "- [ ] test5",
})
-- Get the required module
local queries = neorg.modules.get_module("core.gtd.queries")

describe("GTD - Retrievers:", function()
    it("Get all tasks and projects from buffer", function()
        local tasks = queries.get("tasks", { bufnr = buf })
        assert.equals(3, #tasks)
        local projects = queries.get("projects", { bufnr = buf })
        assert.equals(1, #projects)
    end)

    it("Get all tasks and projects from file name", function()
        local tasks = queries.get("tasks", { filename = filename })
        assert.equals(3, #tasks)
        local projects = queries.get("projects", { filename = filename })
        assert.equals(1, #projects)
    end)

    it("Get all tasks and projects in different files", function()
        local tasks = queries.get("tasks")
        assert.equals(5, #tasks)
        local projects = queries.get("projects")
        assert.equals(2, #projects)
    end)

    it("Exclude files from retriever", function()
        local tasks = queries.get("tasks", { exclude_files = { "test_file_2.norg" } })
        assert.equals(3, #tasks)
        local projects = queries.get("projects", { exclude_files = { "test_file_2.norg" } })
        assert.equals(1, #projects)
    end)

    it("Verify the task and project types and bufnr", function()
        local tasks = queries.get("tasks", { bufnr = buf })
        local projects = queries.get("projects", { bufnr = buf })
        for _, task in pairs(tasks) do
            assert.is_userdata(task[1])
            assert.is_number(task[2])
            assert.equals(buf, task[2])
        end
        for _, project in pairs(projects) do
            assert.is_userdata(project[1])
            assert.is_number(project[2])
            assert.equals(buf, project[2])
        end
    end)

    it("Add metadata to node task", function()
        local projects = queries.get("projects", { bufnr = temp_buf })
        projects = queries.add_metadata(projects, "project")
        assert.equals(1, #projects)
        assert.equals("Project", projects[1].content)

        local tasks = queries.get("tasks", { bufnr = temp_buf })
        tasks = queries.add_metadata(tasks, "task")

        for i, task in ipairs(tasks) do
            assert.equals(i, task.position)
            assert.equals(projects[1].content, task.project)
        end

        assert.equals("test1", tasks[1].content)
        assert.equals("test2", tasks[2].content)
        assert.equals("test3", tasks[3].content)
        assert.equals("test4", tasks[4].content)
        assert.equals("test5", tasks[5].content)

        assert.equals("undone", tasks[1].state)
        assert.equals("undone", tasks[2].state)
        assert.equals("done", tasks[3].state)
        assert.equals("pending", tasks[4].state)
        assert.equals("undone", tasks[5].state)

        assert.equals(2, #tasks[5].contexts)
        assert.is_true(vim.tbl_contains(tasks[5].contexts, "test_context"))
        assert.is_true(vim.tbl_contains(tasks[5].contexts, "test_context2"))

        assert.equals(1, #tasks[5]["time.due"])
        assert.is_true(vim.tbl_contains(tasks[5]["time.due"], "2021-10-10"))
        assert.equals(1, #tasks[5]["time.start"])
        assert.is_true(vim.tbl_contains(tasks[5]["time.start"], "2021-10-11"))
        assert.equals(1, #tasks[5]["waiting.for"])
        assert.is_true(vim.tbl_contains(tasks[5]["waiting.for"], "test_waiting_for"))

        for _, task in pairs(tasks) do
            local keys = vim.tbl_keys(task)
            assert.is_true(vim.tbl_contains(keys, "node"))
            assert.is_true(vim.tbl_contains(keys, "bufnr"))
            assert.is_true(vim.tbl_contains(keys, "content"))
        end
    end)

    it("Get the nodes at cursor", function()
        vim.api.nvim_win_set_buf(0, buf)
        vim.api.nvim_win_set_cursor(0, { 11, 9 })
        local node = queries.get_at_cursor("task")
        assert.is_table(node)

        vim.api.nvim_win_set_cursor(0, { 10, 9 })
        node = queries.get_at_cursor("project")
        assert.is_table(node)

        -- We assume no tasks and projects are found in this line
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        node = queries.get_at_cursor("task")
        assert.is_nil(node)
        node = queries.get_at_cursor("project")
        assert.is_nil(node)
    end)

    it("Sort tasks", function()
        local tasks = queries.get("tasks", { bufnr = temp_buf })
        tasks = queries.add_metadata(tasks, "task")

        local sorted_waiting_for = queries.sort_by("waiting.for", tasks)
        assert.equals(1, vim.tbl_count(sorted_waiting_for["test_waiting_for"]))
        assert.equals(4, vim.tbl_count(sorted_waiting_for["_"]))

        local sorted_projects = queries.sort_by("project", tasks)
        assert.equals(5, vim.tbl_count(sorted_projects["Project"]))

        local sorted_contexts = queries.sort_by("contexts", tasks)
        assert.equals(1, vim.tbl_count(sorted_contexts["test_context"]))
        assert.equals(4, vim.tbl_count(sorted_contexts["_"]))
    end)
end)
