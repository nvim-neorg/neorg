--[[
    File: Defaults
    This file contains all of the most important
    modules that any user would want to have a "just works" experience.
--]]

require("neorg.modules.base")

return neorg.modules.create_meta(
    "core.defaults",
    "core.autocommands",
    "core.neorgcmd",
    "core.keybinds",
    "core.mode",
    "core.norg.qol.todo_items",
    "core.norg.esupports",
    "core.norg.esupports.metagen",
    "core.integrations.treesitter",
    "core.norg.manoeuvre"
)
