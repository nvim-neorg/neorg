--[[
--	ROOT NEORG FILE
--	This file is the beginning of the entire plugin. It's here that everything fires up and starts pumping.
--]]

-- Require the most important modules
require("neorg.callbacks")
require("neorg.events")
require("neorg.modules")

local configuration = require("neorg.config")

-- @Summary Sets up neorg
-- @Description This function takes in a user configuration, parses it, initializes everything and launches neorg if inside a .norg or .org file
-- @Param  config (table) - a table that reflects the structure of configuration.user_configuration
function neorg.setup(config)
    configuration.user_configuration = config or {}

    -- If the file we have entered has a .norg extension
    if vim.fn.expand("%:e") == "norg" then
        -- Then set the filetype and boot up the environment
        neorg.org_file_entered()
    else
        -- Else listen for a BufRead event and fire up the Neorg environment then
        vim.cmd([[
			autocmd BufAdd *.norg ++once :lua require('neorg').org_file_entered()
			command! -nargs=0 Neorg delcommand Neorg | lua require('neorg').org_file_entered()
		]])
    end
end

-- @Summary Neorg startup function
-- @Description This function gets called upon entering a .norg file and loads all of the user-defined modules.
function neorg.org_file_entered()
    -- Extract the module list from the user configuration
    local module_list = configuration.user_configuration and configuration.user_configuration.load or {}

    -- If we have already started Neorg or if we haven't defined any modules to load then bail
    if neorg.configuration.started or not module_list or vim.tbl_isempty(module_list) then
        return
    end

    -- Create a new global instance of the neorg logger
    require("neorg.external.log").new(configuration.user_configuration.logger or log.get_default_config(), true)

    -- Loop through all the modules and load them one by one
    require("plenary.async_lib.async").async(function()
        -- If the user has defined a post-load hook then execute it
        if configuration.user_configuration.hook then
            configuration.user_configuration.hook()
        end

        -- Go through each defined module and grab its configuration
        for name, module in pairs(module_list) do
            -- If the module's data is not empty and we have not defined a config table then it probably means there's junk in there
            if not vim.tbl_isempty(module) and not module.config then
                log.warn(
                    "Potential bug detected in",
                    name,
                    "- nonstandard tables found in the module definition. Did you perhaps mean to put these tables inside of the config = {} table?"
                )
            end

            -- Apply the configuration
            configuration.modules[name] = vim.tbl_deep_extend(
                "force",
                configuration.modules[name] or {},
                module.config or {}
            )
        end

        -- After all configurations are merged proceed to actually load the modules
        for name, _ in pairs(module_list) do
            -- If it could not be loaded then halt
            if not neorg.modules.load_module(name) then
                log.fatal("Halting loading of modules due to error...")
                break
            end
        end

        -- Goes through each loaded module and invokes neorg_post_load()
        for _, module in pairs(neorg.modules.loaded_modules) do
            module.neorg_post_load()
        end
    end)()()

    -- Set this variable to prevent Neorg from loading twice
    neorg.configuration.started = true
end

return neorg
