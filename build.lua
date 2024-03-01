-- This build.lua exists to bridge luarocks installation for lazy.nvim users.
-- It's main purposes are:
-- - Shelling out to luarocks.nvim for installation
-- - Installing neorg as a rock (including dependencies)

-- Important note: we execute the build code in a vim.schedule
-- to defer the execution and ensure that the runtimepath is appropriately set.

vim.schedule(function()
    local ok, luarocks = pcall(require, "luarocks.rocks")

    assert(ok, "Unable to install neorg: required dependency `camspiers/luarocks` not found!")

    -- local version = require("neorg.core.config").version

    luarocks.ensure({
        "nvim-nio ~> 1.7",
        "lua-utils.nvim == 1.0.2",
    })

    require("neorg").setup_after_build()
end)
