describe(
    "initial test to see if CI works (cannot be tested on a branch, must be tested on main, `act` doesn't work here, help)",
    function()
        local _ = require("neorg.modules.core.integrations.treesitter.module")

        it("should be working", function()
            assert.truthy("Yessir.")
        end)
    end
)
