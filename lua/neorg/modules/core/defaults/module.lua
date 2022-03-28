--[[
    File: Defaults
    Summary: Metamodule for storing the most necessary modules.
    Show: false.
    ---
This file contains all of the most important
modules that any user would want to have a "just works" experience.
--]]

require("neorg.modules.base")

return neorg.modules.create_meta(
    "core.defaults",
    "core.syntax",
    "core.autocommands",
    "core.neorgcmd",
    "core.keybinds",
    "core.mode",
    "core.norg.qol.todo_items",
    "core.norg.esupports.indent",
    "core.norg.esupports.metagen",
    "core.norg.esupports.hop",
    "core.integrations.treesitter",
    "core.storage",
    "core.norg.news"
)
