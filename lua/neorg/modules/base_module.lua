--[[
--    BASE FILE FOR MODULES
--    This file contains the base module implementation
--]]

local neorg = require("neorg.core")


local base = {
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
        version = neorg.configuration.version,
    },

    -- Configuration for the module
    config = {
        -- Private module configuration, cannot be changed by other modules or by the user
        private = { --[[
            config_option = false,
            option_group = { sub_option = true }
        --]] },

        -- Public config, can be changed by modules and the user
        public = { --[[
            config_option = false,
            option_group = { sub_option = true }
        --]] },

        -- This table houses all the changes the user made to the public table,
        -- useful for when you want to know exactly what the user tinkered with.
        -- Shouldn't be commonly used.
        custom = {},
    },

    -- Event data regarding the current module
    events = {
        -- The events that the module is subscribed to
        subscribed = { --[[
            ["core.test"] = { -- The name of the module that has events bound to it
                test_event = true, -- Subscribes to event core.test.events.test_event
                other_event = true -- Subscribes to event core.test.events.other_event
            }
        --]] },

        -- The events that the module itself has defined
        defined = { --[[
            -- Creates an event of type category.module.events.my_event
            my_event = { event_data }
        --]] },
    },

    -- If you ever require a module through the return value of the setup() function,
    -- All of the modules' public APIs will become available here
    required = { --[[
        ["core.test"] = {
            -- Their public API here...
        },
        ["core.some_other_plugin"] = {
            -- Their public API here...
        }
    --]] },

    -- Example bits of code that the user can look through
    examples = { --[[
        a_cool_test = function()
            print("Some code!")
        end
    --]] },
}

-- Invoked before any initial loading happens
function base.setup()
    return {
        success = true,
        requires = {},
        replaces = nil,
        replace_merge = false
    }
end

-- Invoked after the module has been configured
function base.load() end

-- Invoked whenever an event that the module has subscribed to triggers
-- callback function with a "event" parameter
function base.on_event() end

-- Invoked after all plugins are loaded
function base.neorg_post_load() end

return base
