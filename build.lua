-- This build.lua exists to bridge luarocks installation for lazy.nvim users.
-- It's main purposes are:
-- - Shelling out to luarocks.nvim for installation
-- - Installing neorg as a rock (including dependencies)

local ok, luarocks = pcall(require, "luarocks.rocks")

assert(ok, "Unable to install neorg: required dependency `camspiers/luarocks` not found!")

local version = require("neorg.core.config").version

luarocks.ensure({ "neorg ~> " .. version })
