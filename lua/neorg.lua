--[[
--    ROOT NEORG FILE
--    This file is the beginning of the entire plugin. It's here that everything fires up and starts pumping.
--]]

-- Require the most important modules
local neorg = require("neorg.core")
local config = neorg.config

require("neorg.events") -- TODO: Move to its own local core module
require("neorg.modules") -- TODO: Move to its own local core module

--- This function takes in a user config, parses it, initializes everything and launches neorg if inside a .norg or .org file
---@param config table #A table that reflects the structure of config.user_config
function neorg.setup(cfg)
    config.user_config = vim.tbl_deep_extend("force", config.user_config, cfg or {})

    -- Create a new global instance of the neorg logger
    require("neorg.external.log").new(config.user_config.logger or log.get_default_config(), true)

    -- Make the Neorg filetype detectable through `vim.filetype`.
    -- TODO: Make a PR to Neovim to natively support the org and norg
    -- filetypes.
    vim.filetype.add({
        extension = {
            norg = "norg",
        },
    })

    -- If the file we have entered has a .norg extension
    if vim.fn.expand("%:e") == "norg" or not config.user_config.lazy_loading then
        -- Then boot up the environment
        neorg.org_file_entered(false)
    else
        -- Else listen for a BufReadPost event and fire up the Neorg environment
        vim.cmd([[
            autocmd BufAdd *.norg ++once :lua require('neorg').org_file_entered(false)
            command! -nargs=* NeorgStart delcommand NeorgStart | lua require('neorg').org_file_entered(true, <q-args>)
        ]])

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "norg",
            callback = function()
                neorg.org_file_entered(false)
            end,
        })
    end
end

--- This function gets called upon entering a .norg file and loads all of the user-defined modules.
---@param manual boolean #If true then the environment was kickstarted manually by the user
---@param arguments string? #A list of arguments in the format of "key=value other_key=other_value"
function neorg.org_file_entered(manual, arguments)
    -- Extract the module list from the user config
    local module_list = config.user_config and config.user_config.load or {}

    -- If we have already started Neorg or if we haven't defined any modules to load then bail
    if config.started or not module_list or vim.tbl_isempty(module_list) then
        return
    end

    -- If the user has defined a post-load hook then execute it
    if config.user_config.hook then
        config.user_config.hook(manual, arguments)
    end

    -- If Neorg was loaded manually (through `:NeorgStart`) then set this flag to true
    config.manual = manual

    -- If the user has supplied any Neorg environment variables
    -- then parse those here
    if arguments and arguments:len() > 0 then
        for key, value in arguments:gmatch("([%w%W]+)=([%w%W]+)") do
            config.arguments[key] = value
        end
    end

    -- Go through each defined module and grab its config
    for name, module in pairs(module_list) do
        -- If the module's data is not empty and we have not defined a config table then it probably means there's junk in there
        if not vim.tbl_isempty(module) and not module.config then
            log.warn(
                "Potential bug detected in",
                name,
                "- nonstandard tables found in the module definition. Did you perhaps mean to put these tables inside of the config = {} table?"
            )
        end

        -- Apply the config
        config.modules[name] =
            vim.tbl_deep_extend("force", config.modules[name] or {}, module.config or {})
    end

    -- After all config are merged proceed to actually load the modules
    local load_module = neorg.modules.load_module
    for name, _ in pairs(module_list) do
        -- If it could not be loaded then halt
        if not load_module(name) then
            log.warn("Recovering from error...")
            neorg.modules.loaded_modules[name] = nil
        end
    end

    -- Goes through each loaded module and invokes neorg_post_load()
    for _, module in pairs(neorg.modules.loaded_modules) do
        module.neorg_post_load()
    end

    -- Set this variable to prevent Neorg from loading twice
    config.started = true

    -- Lets the entire Neorg environment know that Neorg has started!
    neorg.events.broadcast_event({
        type = "core.started",
        split_type = { "core", "started" },
        filename = "",
        filehead = "",
        cursor_position = { 0, 0 },
        referrer = "core",
        line_content = "",
        broadcast = true,
    })

    -- Sometimes external plugins prefer hooking in to an autocommand
    vim.api.nvim_exec_autocmds("User", {
        pattern = "NeorgStarted",
    })
end

--- Returns whether or not Neorg is loaded
---@return boolean
function neorg.is_loaded()
    return config.started
end

return neorg
