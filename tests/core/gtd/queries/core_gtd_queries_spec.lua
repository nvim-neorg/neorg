require("neorg").setup({
    load = { ["core.gtd.base"] = {} },
})

describe("GTD - Retrievers:", function()
    -- vim.cmd(":NeorgStart silent=true")
    neorg.org_file_entered(false)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "test.norg")
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, {
        "this is a test",
        "- [ ] test1",
        "- [ ] test2",
        "- [x] test3",
    })
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
