require("neorg.modules.base")
local utils = require("neorg.external.helpers")

local module = neorg.modules.create("core.gtd.base")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.ui",
            "core.norg.dirman",
        },
    }
end

module = utils.require(module, "displayers")
module = utils.require(module, "add_to_inbox")

return module
