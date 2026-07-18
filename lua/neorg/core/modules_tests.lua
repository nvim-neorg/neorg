local tests = require("neorg.tests")

describe("core.modules.create_event", function()
    local neorg = tests.neorg_with("core.dirman", {
        workspaces = { test = "./test-workspace" },
    })
    local modules = neorg.modules

    it("does not crash when the target buffer is not shown in a window", function()
        -- Put the current window on a buffer with a cursor row past the end of `bufid`.
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a", "b", "c", "d", "e" })
        vim.api.nvim_win_set_cursor(0, { 5, 0 })

        -- `bufid` has a single line and is not displayed in any window, mirroring an event
        -- broadcast during startup (e.g. `set_workspace`).
        local bufid = vim.api.nvim_create_buf(false, true)

        local event = modules.create_event(
            { name = "core.dirman" },
            "core.dirman.events.workspace_changed",
            nil,
            { buf = bufid }
        )

        assert.same({ 0, 0 }, event.cursor_position)
        assert.equal("", event.line_content)
    end)
end)
