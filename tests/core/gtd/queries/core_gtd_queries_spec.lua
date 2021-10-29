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

-- Get the required module
local queries = neorg.modules.get_module("core.gtd.queries")

describe("GTD - Retrievers:", function()
    it("Get all tasks from buffer", function()
        local tasks = queries.get("tasks", { bufnr = buf })
        assert.equals(3, #tasks)
    end)

    it("Get all tasks from file name", function()
        local tasks = queries.get("tasks", { filename = filename })
        assert.equals(3, #tasks)
    end)

    it("Get all tasks in different files", function()
        local tasks = queries.get("tasks")
        assert.equals(5, #tasks)
    end)

    it("Exclude files from retriever", function()
        local tasks = queries.get("tasks", { exclude_files = { "test_file_2.norg" } })
        assert.equals(3, #tasks)
    end)

    it("Verify the task types and bufnr", function()
        local tasks = queries.get("tasks", { bufnr = buf })
        for _, task in pairs(tasks) do
            assert.is_userdata(task[1])
            assert.is_number(task[2])
            assert.equals(buf, task[2])
        end
    end)

    it("Add metadata to node task", function()
        local _buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(_buf, "test.norg")
        vim.api.nvim_buf_set_lines(_buf, 0, 0, false, {
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
        local tasks = queries.get("tasks", { bufnr = _buf })
        tasks = queries.add_metadata(tasks, "task")

        for i, task in ipairs(tasks) do
            assert.equals(i, task.position)
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
end)
