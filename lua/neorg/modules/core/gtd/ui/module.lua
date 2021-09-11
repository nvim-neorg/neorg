require("neorg.modules.base")
local utils = require("neorg.external.helpers")

local module = neorg.modules.create("core.gtd.ui")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.ui",
            "core.norg.dirman",
            "core.gtd.queries",
        },
    }
end

module = utils.require(module, "displayers")
module = utils.require(module, "add_to_inbox")
module = utils.require(module, "selection_popups")

return module
