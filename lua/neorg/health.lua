return {
    check = function()
        local config = require("neorg.core").config.user_config
        local modules = require("neorg.core").modules.loaded_modules

        vim.health.start("neorg")
        vim.health.info("Checking configuration...")

        if config.load == nil or vim.tbl_isempty(config.load) then
            vim.health.ok("Empty configuration provided: Neorg will load `core.defaults` by default.")
        elseif type(config.load) ~= "table" then
            vim.health.error("Invalid data type provided. `load` table should be a dictionary of modules!")
        else
            vim.health.info("Checking `load` table...")

            for key, value in pairs(config.load) do
                if type(key) ~= "string" then
                    vim.health.error(
                        string.format(
                            "Invalid data type provided within `load` table! Expected a module name (e.g. `core.defaults`), got a %s instead.",
                            type(key)
                        )
                    )
                elseif not modules[key] then
                    vim.health.warn(
                        string.format(
                            "You are attempting to load a module `%s` which is not recognized by Neorg at this time. You may receive an error upon launching Neorg."
                        )
                    )
                elseif type(value) ~= "table" then
                    vim.health.error(
                        string.format(
                            "Invalid data type provided within `load` table for module `%s`! Expected module data (e.g. `{ config = { ... } }`), got a %s instead.",
                            key,
                            type(key)
                        )
                    )
                elseif value.config and type(value.config) ~= "table" then
                    vim.health.error(
                        string.format(
                            "Invalid data type provided within data table for module `%s`! Expected configuration data (e.g. `config = { ... }`), but `config` was set to a %s instead.",
                            key,
                            type(key)
                        )
                    )
                elseif #vim.tbl_keys(value) > 1 and value.config ~= nil then
                    vim.health.warn(
                        string.format(
                            "Unexpected extra data provided to module `%s` - each module only expects a `config` table to be provided, nothing else.",
                            key
                        )
                    )
                elseif (#vim.tbl_keys(value) > 0 and value.config == nil) or #vim.tbl_keys(value) > 1 then
                    vim.health.warn(
                        string.format(
                            "Misplaced configuration data for module `%s` - it seems like you forgot to put your module configuration inside a `config = {}` table?",
                            key
                        )
                    )
                else
                    vim.health.ok(string.format("Module declaration `%s` is well-formed", key))
                end
            end

            -- TODO(vhyrro): Check the correctness of the logger table too
            if config.logger == nil or vim.tbl_isempty(config.logger) then
                vim.health.ok("Default configuration for logger provided, Neorg will not output debug info.")
            end
        end

        vim.health.info("Checking existence of dependencies...")

        if pcall(require, "lazy") then
            if not (pcall(require, "luarocks-nvim")) then
                vim.health.error(
                    "Required dependency `vhyrro/luarocks.nvim` not found! Neither `theHamsta/nvim_rocks` nor `camspiers/luarocks` are compatible. Check installation instructions in the README for how to fix the error."
                )
            else
                vim.health.ok("Required dependency `vhyrro/luarocks` found!")

                vim.health.info("Checking existence of luarocks dependencies...")

                local has_lua_utils = (pcall(require, "lua-utils"))

                if not has_lua_utils then
                    vim.health.error(
                        "Critical dependency `lua-utils.nvim` not found! Please run `:Lazy build luarocks.nvim` and then `:Lazy build neorg`! Neorg will refuse to load."
                    )
                else
                    vim.health.ok("Critical dependencies are installed. You are free to use Neorg!")
                    vim.health.warn("If you ever encounter errors please rerun `:Lazy build neorg` again :)")
                end
            end
        else
            vim.health.ok("Using plugin manager other than lazy, no need for the `vhyrro/luarocks.nvim` dependency.")
            vim.health.warn(
                "If you are on an unsupported plugin manager you may still need the plugin for Neorg to function."
            )
        end
    end,
}
