---@diagnostic disable: undefined-global
local config = require("tests.core.gtd.queries.config")

-- Get the required module
local queries = neorg.modules.get_module("core.gtd.queries")

describe("CORE.GTD.QUERIES - Modifiers:", function()
    it("Modify a task", function()
        local tasks = queries.get("tasks", { bufnr = config.temp_buf })
        tasks = queries.add_metadata(tasks, "task", { extract = false })
        local task = tasks[5]

        task = queries.modify(task, "task", "waiting.for", { "new_waiting_for" }, { tag = "#waiting.for" })
        task = queries.modify(task, "task", "contexts", { "new_context" }, { tag = "#contexts" })
        task = queries.modify(task, "task", "content", "new content")

        tasks = queries.get("tasks", { bufnr = config.temp_buf })
        tasks = queries.add_metadata(tasks, "task", { extract = true })

        assert.equals("new_waiting_for", tasks[5]["waiting.for"][1])
        assert.is_true(vim.tbl_contains(tasks[5].contexts, "new_context"))
        assert.equals("new content", tasks[5].content)
    end)

    it("Modify a project", function()
        local projects = queries.get("projects", { bufnr = config.temp_buf })
        projects = queries.add_metadata(projects, "project", { extract = false })
        local project = projects[1]

        project = queries.modify(project, "project", "content", "new content")

        projects = queries.get("projects", { bufnr = config.temp_buf })
        projects = queries.add_metadata(projects, "project", { extract = true })

        assert.equals("new content", projects[1].content)
    end)

    it("Delete content from a task", function()
        local tasks = queries.get("tasks", { bufnr = config.temp_buf })
        tasks = queries.add_metadata(tasks, "task", { extract = false })
        local task = tasks[5]

        assert.is_table(task["waiting.for"])

        task = queries.delete(task, "task", "waiting.for")

        tasks = queries.get("tasks", { bufnr = config.temp_buf })
        tasks = queries.add_metadata(tasks, "task", { extract = true })

        assert.is_nil(tasks[5]["waiting_for"])
    end)
end)
