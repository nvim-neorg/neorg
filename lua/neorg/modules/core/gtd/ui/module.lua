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

    * HELPERS:
        Some helpers...

    * SELECTION_POPUPS:
        UI components that use selection popups
        - show_views_popup
        - edit_task

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
            "core.integrations.treesitter"
        },
        imports = {
            "displayers",
            "helpers",
            "views_popup_helpers",
            "edit_popup_helpers",
            "selection_popups",
        },
    }
end

return module
