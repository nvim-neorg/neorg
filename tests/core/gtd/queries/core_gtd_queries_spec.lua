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
            assert.equals("userdata", type(task[1]))
            assert.equals("number", type(task[2]))
            assert.equals(buf, task[2])
        end
    end)
end)
