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
    "core.esupports.hop",
    "core.esupports.indent",
    "core.esupports.metagen",
    "core.integrations.treesitter",
    "core.itero",
    "core.journal",
    "core.keybinds",
    "core.looking-glass",
    "core.mode",
    "core.neorgcmd",
    "core.news",
    "core.pivot",
    "core.promo",
    "core.qol.toc",
    "core.qol.todo_items",
    "core.storage",
    "core.syntax",
    "core.tangle",
    "core.upgrade"
)
