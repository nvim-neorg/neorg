--[[
    file: Upgrade
    title: Upgrade Tool for Neorg
    summary: Converts old versions of the Norg syntax to newer ones.
    ---
When dealing with changes to the Norg syntax, it is very inconvenient to have to manually
update all of your files, especially if you're not a regex wizard.

To alleviate this problem, the upgrade tool serves as a way to automate the process.

There are two main commands that are exposed for use:
- `:Neorg upgrade current-file` - takes the current file and upgrades it to the new syntax.
  Will ask for a backup.
- `:Neorg upgrade current-directory` - upgrades all files in the current directory. Asks
   for a backup and displays the current directory so no mistakes are made.

When a backup is requested, Neorg backs up the file to `<filename>.old.norg`, then upgrades
the original file/directory in-place.
--]]

local neorg = require("neorg.core")
local log, modules = neorg.log, neorg.modules

local module = modules.create("core.upgrade")

module.setup = function()
    log.error(
        "The `core.upgrade` module has been deprecated and is no longer in use. Please remove it from your loaded list."
    )

    return {
        success = false,
    }
end

return module
