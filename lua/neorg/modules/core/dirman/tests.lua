local tests = require("neorg.tests")
local Path = require("pathlib")

describe("core.dirman tests", function()
    local dirman = tests
        .neorg_with("core.dirman", {
            workspaces = {
                test = "./test-workspace",
            },
        }).modules
        .get_module("core.dirman")

    describe("workspace-related functions", function()
        it("properly expands workspace paths", function()
            assert.same(dirman.get_workspaces(), {
                default = Path.cwd(),
                test = Path.cwd() / "test-workspace",
            })
        end)

        it("properly sets and retrieves workspaces", function()
            assert.is_true(dirman.set_workspace("test"))

            assert.equal(dirman.get_current_workspace()[1], "test")
        end)

        it("properly creates and writes files", function()
            local ws_path = (Path.cwd() / "test-workspace")

            dirman.create_file("example-file", "test", {
                no_open = true,
            })

            finally(function()
                vim.fn.delete(ws_path:tostring(), "rf")
            end)

            assert.equal(vim.fn.filereadable((ws_path / "example-file.norg"):tostring()), 1)
        end)
    end)
end)
