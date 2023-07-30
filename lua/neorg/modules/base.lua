--[[
--    BASE FILE FOR MODULES
--    This file contains the base module implementation
--]]

local neorg = require("neorg.core")
neorg.modules = {}

--- Returns a new Neorg module, exposing all the necessary function and variables
---@param name string #The name of the new module. Make sure this is unique. The recommended naming convention is category.module_name or category.subcategory.module_name
---@param imports? string[] #A list of imports to attach to the module. Import data is requestable via `module.required`. Use paths relative to the current module.
function neorg.modules.create(name, imports)
    local new_module = {

        -- Invoked before any initial loading happens
        setup = function()
            return { success = true, requires = {}, replaces = nil, replace_merge = false }
        end,

        -- Invoked after the module has been configured
        load = function() end,

        -- Invoked whenever an event that the module has subscribed to triggers
        -- callback function with a "event" parameter
        on_event = function() end,

        -- Invoked after all plugins are loaded
        neorg_post_load = function() end,

        -- The name of the module, note that modules beginning with core are neorg's inbuilt modules
        name = "core.default",

        -- The path of the module, can be used in require() statements
        path = "neorg.modules.core.default.module",

        -- A convenience table to place all of your private variables that you don't want to expose here.
        private = {},

        -- Every module can expose any set of information it sees fit through the public field
        -- All functions and variables declared in this table will be visible to any other module loaded
        public = {
            -- Current Norg version that this module supports.
            -- Your module will use this version if not specified, but you can override it.
            -- Overriding it will mean that your module is only compatible with the overriden Norg revision.
            -- E.g: setting version = "1.0.0" will mean that your module requires Norg 1.0.0+ to operate
            version = require("neorg.config").norg_version,
        },

        -- Configuration for the module
        config = {
            private = { -- Private module configuration, cannot be changed by other modules or by the user
                --[[
                config_option = false,

                ["option_group"] = {
                    sub_option = true
                }
                --]]
            },

            public = { -- Public config, can be changed by modules and the user
                --[[
                config_option = false,

                ["option_group"] = {
                    sub_option = true
                }
                --]]
            },

            -- This table houses all the changes the user made to the public table,
            -- useful for when you want to know exactly what the user tinkered with.
            -- Shouldn't be commonly used.
            custom = {},
        },

        -- Event data regarding the current module
        events = {
            subscribed = { -- The events that the module is subscribed to
                --[[
                ["core.test"] = { -- The name of the module that has events bound to it
                    ["test_event"]  = true, -- Subscribes to event core.test.events.test_event

                    ["other_event"] = true -- Subscribes to event core.test.events.other_event
                }
                --]]
            },
            defined = { -- The events that the module itself has defined
                --[[
                ["my_event"] = { event_data } -- Creates an event of type category.module.events.my_event
                --]]
            },
        },

        -- If you ever require a module through the return value of the setup() function,
        -- All of the modules' public APIs will become available here
        required = {
            --[[
            ["core.test"] = {
                -- Their public API here...
            },

            ["core.some_other_plugin"] = {
                -- Their public API here...
            }

            --]]
        },

        -- Example bits of code that the user can look through
        examples = {
            --[[
            a_cool_test = function()
                print("Some code!")
            end
            --]]
        },

        -- Imported submodules of the given module.
        -- Contrary to `required`, which only exposes the public API of a module,
        -- imported modules can be accessed in their entirety.
        imported = {
            --[[
            ["my.module.submodule"] = { ... },
            --]]
        },
    }

    if imports then
        for _, import in ipairs(imports) do
            local fullpath = table.concat({ name, import }, ".")

            if not neorg.modules.load_module(fullpath) then
                log.error("Unable to load import '" .. fullpath .. "'! An error occured (see traceback below):")
                assert(false) -- Halt execution, no recovering from this error...
            end

            new_module.imported[fullpath] = neorg.modules.loaded_modules[fullpath]
        end
    end

    if name then
        new_module.name = name
        new_module.path = "neorg.modules." .. name
    end

    return new_module
end

--- Constructs a metamodule from a list of submodules. Metamodules are modules that can autoload batches of modules at once.
---@param name string #The name of the new metamodule. Make sure this is unique. The recommended naming convention is category.module_name or category.subcategory.module_name
-- @Param  ... (varargs) - a list of module names to load.
function neorg.modules.create_meta(name, ...)
    local module = neorg.modules.create(name)

    require("neorg.modules")

    module.config.public.enable = { ... }

    module.setup = function()
        return { success = true }
    end

    module.load = function()
        module.config.public.enable = (function()
            -- If we haven't define any modules to disable then just return all enabled modules
            if not module.config.public.disable then
                return module.config.public.enable
            end

            local ret = {}

            -- For every enabled module
            for _, mod in ipairs(module.config.public.enable) do
                -- If that module does not exist in the disable table (ie. it is enabled) then add it to the `ret` table
                if not vim.tbl_contains(module.config.public.disable, mod) then
                    table.insert(ret, mod)
                end
            end

            -- Return the table containing all the modules we would like to enable
            return ret
        end)()

        -- Go through every module that we have defined in the metamodule and load it!
        for _, mod in ipairs(module.config.public.enable) do
            neorg.modules.load_module(mod)
        end
    end

    return module
end
