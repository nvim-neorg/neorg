return {
    check = function()
        local config = require("neorg.core").config.user_config
        local modules = require("neorg.core.modules")

        vim.health.start("Neorg Configuration")

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
                elseif not modules.load_module(key) then
                    vim.health.warn(
                        string.format(
                            "You are attempting to load a module `%s` which is not recognized by Neorg at this time. You may receive an error upon launching Neorg.",
                            key
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
                    vim.health.ok(string.format("Module declaration for `%s` is well-formed", key))
                end
            end

            -- TODO(vhyrro): Check the correctness of the logger table too
            if config.logger == nil or vim.tbl_isempty(config.logger) then
                vim.health.ok("Default configuration for logger provided, Neorg will not output debug info.")
            end
        end

        vim.health.start("Neorg Dependencies")

        if vim.fn.executable("luarocks") then
            vim.health.ok("`luarocks` is installed.")
        else
            vim.health.error(
                "`luarocks` not installed on your system! Please consult the Neorg README for installation instructions."
            )
        end

        vim.health.start("Neorg Keybinds")

        modules.load_module("core.keybinds")
        local keybinds = modules.get_module("core.keybinds")
        local keybinds_config = modules.get_module_config("core.keybinds")

        if keybinds_config.default_keybinds then
            local key_healthcheck = keybinds.health()

            if key_healthcheck.preset_exists then
                vim.health.info(string.format("Neorg is configured to use keybind preset `%s`", keybinds_config.preset))
            else
                vim.health.error(
                    string.format(
                        "Invalid configuration found: preset `%s` does not exist! Did you perhaps make a typo?",
                        keybinds_config.preset
                    )
                )
                return
            end

            for remap_key, remap_rhs in vim.spairs(key_healthcheck.remaps) do
                vim.health.ok(
                    string.format(
                        "Action `%s` (bound to `%s` by default) has been remapped to something else in your configuration.",
                        remap_rhs,
                        remap_key
                    )
                )
            end

            local ok = true

            for conflict_key, rhs in vim.spairs(key_healthcheck.conflicts) do
                vim.health.warn(
                    string.format(
                        "Key `%s` conflicts with a key bound by the user. Neorg will not bind this key.",
                        conflict_key
                    ),
                    string.format("consider mapping `%s` to a different key than the one bound by Neorg.", rhs)
                )
                ok = false
            end

            if ok then
                vim.health.ok("No keybind conflicts found.")
            end
        else
            vim.health.ok("Neorg is not configured to set any default keybinds.")
        end
    end,
}
