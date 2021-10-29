---@diagnostic disable: undefined-global
local config = require("tests.core.gtd.queries.config")

-- Get the required module
local queries = neorg.modules.get_module("core.gtd.queries")

describe("CORE.GTD.QUERIES - Creators:", function()
    it("Creates a task", function()
        local task = {
            ["waiting.for"] = { "test" },
            content = "test_content",
        }
        queries.create("task", task, config.buf, 0, false, { no_save = true })

        local tasks = queries.get("tasks", { bufnr = config.buf })
        tasks = queries.add_metadata(tasks, "task")

        assert.equals(1, #tasks)
        assert.is_true(vim.tbl_contains(tasks[1]["waiting.for"], "test"))
        assert.equals("test_content", tasks[1].content)
    end)
end)
