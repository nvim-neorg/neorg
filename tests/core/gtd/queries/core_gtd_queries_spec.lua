require("neorg").setup({
    load = { ["core.gtd.base"] = {}, ["core.norg.dirman"] = {} },
})

neorg.org_file_entered(false)

local workspace = neorg.modules.get_module("core.norg.dirman").get_workspace("default")
local uri = vim.uri_from_fname(workspace .. "/tests/core/gtd/queries/test_file.norg")
local buf = vim.uri_to_bufnr(uri)

describe("GTD - Retrievers:", function()
    local queries = neorg.modules.get_module("core.gtd.queries")

    it("Get all tasks from buffer", function()
        local tasks = queries.get("tasks", { bufnr = buf })
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
