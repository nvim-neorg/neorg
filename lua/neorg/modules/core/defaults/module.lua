--[[
    File: Defaults
    Summary: Metamodule for storing the most necessary modules.
    Internal: true
    ---
This file contains all of the most important
modules that any user would want to have a "just works" experience.
--]]

require("neorg.modules.base")

return neorg.modules.create_meta(
    "core.defaults",
    "core.autocommands",
    "core.clipboard",
    "core.clipboard.code-blocks",
    "core.integrations.treesitter",
    "core.itero",
    "core.keybinds",
    "core.looking-glass",
    "core.mode",
    "core.neorgcmd",
    "core.norg.esupports.hop",
    "core.norg.esupports.indent",
    "core.norg.esupports.metagen",
    "core.norg.journal",
    "core.norg.news",
    "core.norg.qol.toc",
    "core.norg.qol.todo_items",
    "core.promo",
    "core.storage",
    "core.syntax",
    "core.tangle",
    "core.upgrade"
)
