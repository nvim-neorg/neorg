--[[
--    BASE FILE FOR MODULES
--    This file contains the base module implementation
--]]

neorg.modules = {}

neorg.modules.module_base = {

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
        -- Current neorg version. Your module will use this version if not specified, but you can override it.
        -- Overriding it will mean that your module is only compatible with the overriden neorg version
        -- E.g: setting version = "1.3.0" will mean that your module requires norg 1.3.0+ to operate
        version = require("neorg.config").version,
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
                EXAMPLE DEFINITION:
                [ "core.test" ] = { -- The name of the module that has events bound to it
                    [ "test_event" ] = true, -- Subscribes to event core.test.events.test_event
                    [ "other_event" ] = true -- Subscribes to event core.test.events.other_event
                }
            --]]
        },
        defined = { -- The events that the module itself has defined

            --[[
                EXAMPLE DEFINITION:
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
}

--- Returns a module that derives from neorg.modules.module_base, exposing all the necessary function and variables
---@param name string #The name of the new module. Make sure this is unique. The recommended naming convention is category.module_name or category.subcategory.module_name
function neorg.modules.create(name)
    local new_module = vim.deepcopy(neorg.modules.module_base)

    -- TODO: Comment this black magic

    local t = {
        from = function(self, parent, type)
            local prevname = self.real().name

            local parent_copy = vim.deepcopy(parent.real())

            for tbl_name, tbl in pairs(parent_copy) do
                if _G.type(tbl) == "table" and vim.tbl_isempty(tbl) then
                    parent_copy[tbl_name] = nil
                end
            end

            new_module = vim.tbl_deep_extend(type or "force", new_module, parent_copy)

            if not type then
                new_module.setup = function()
                    return { success = true }
                end

                new_module.load = function() end
                new_module.on_event = function() end
                new_module.neorg_post_load = function() end
            end

            new_module.name = prevname

            return self
        end,

        real = function()
            return new_module
        end,

        setreal = function(new)
            new_module = new
        end,
    }

    if name then
        new_module.name = name
        new_module.path = "neorg.modules." .. name
    end

    return setmetatable(t, {
        __newindex = function(_, key, value)
            if type(value) ~= "table" then
                new_module[key] = value
            else
                new_module[key] = vim.tbl_deep_extend("force", new_module[key], value or {})
            end
        end,

        __index = function(_, key)
            return t.real()[key]
        end,
    })
end

function neorg.modules.extend(name, parent)
    local module = neorg.modules.create(name)

    local realmodule = rawget(module, "real")()

    if parent then
        local path = realmodule.path
        realmodule = vim.tbl_deep_extend("force", realmodule, neorg.modules.loaded_modules[parent].real())
        realmodule.name, realmodule.path = name, path
    end

    realmodule.setup = nil
    realmodule.load = nil
    realmodule.on_event = nil
    realmodule.neorg_post_load = nil

    module.setreal(realmodule)

    module.extension = true

    return module
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
