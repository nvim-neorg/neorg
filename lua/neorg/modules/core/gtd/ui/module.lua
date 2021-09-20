--[[
    UI GTD components

REQUIRES:
    - core.ui                       to use ui stuff
    - core.norg.dirman              for file operations
    - core.gtd.queries              to use gtd queries

SUBMODULES:
    * DISPLAYERS:
        UI components to display gtd's useful data
        - display_today_tasks
        - display_waiting_for
        - display_contexts
        - display_projects

    * ADD_TO_INBOX:
        UI prompt to add a task in inbox file
        - add_task_to_inbox
    * SELECTION_POPUPS:
        UI components that use selection popups
        - show_quick_actions

--]]

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
module = utils.require(module, "selection_popups_helpers")
module = utils.require(module, "selection_popups")

return module
