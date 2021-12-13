---@diagnostic disable: undefined-global
local config = require("tests.config")

-- Get the required module
local queries = neorg.modules.get_module("core.gtd.queries")

describe("CORE.GTD.QUERIES - Creators:", function()
    it("Creates a task", function()
        local task = {
            ["waiting.for"] = { "test" },
            content = "test_content",
        }
        local buf = config.get_void_buf()
        queries.create("task", task, buf, { 0, 0 }, false, { no_save = true })

        local tasks = queries.get("tasks", { bufnr = buf })
        tasks = queries.add_metadata(tasks, "task")

        assert.equals(1, #tasks)
        assert.is_true(vim.tbl_contains(tasks[1]["waiting.for"], "test"))
        assert.equals("test_content", tasks[1].content)

        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("Creates a project", function()
        local project = {
            content = "test_content",
            contexts = { "test" },
        }
        local buf = config.get_void_buf()

        queries.create("project", project, buf, { 0, 0 }, false, { no_save = true, newline = true })

        local projects = queries.get("projects", { bufnr = buf })
        projects = queries.add_metadata(projects, "project")

        assert.equals(1, #projects)
        assert.is_true(vim.tbl_contains(projects[1]["contexts"], "test"))
        assert.equals("test_content", projects[1].content)

        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("Get the end of the project", function()
        local projects = queries.get("projects", { bufnr = config.temp_buf })
        projects = queries.add_metadata(projects, "project")

        local location = queries.get_end_project(projects[1].node, projects[1].bufnr)
        local lines = vim.api.nvim_buf_line_count(config.temp_buf)
        assert.equals(lines, location[1])
    end)

    it("Get the end of the document content", function()
        local location = queries.get_end_document_content(config.temp_buf)
        local lines = vim.api.nvim_buf_line_count(config.temp_buf)
        assert.equals(lines, location)
    end)
end)
