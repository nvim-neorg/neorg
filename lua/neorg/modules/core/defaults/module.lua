--[[
    file: Defaults
    summary: Metamodule for storing the most necessary modules.
    internal: true
    ---
This file contains all of the most important modules that any user would want
to have a "just works" experience.

Individual entries can be disabled via the "disable" flag:
```lua
load = {
    ["core.defaults"] = {
        config = {
            disable = {
                -- module list goes here
                "core.autocommands",
                "core.itero",
            },
        },
    },
}
```
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
