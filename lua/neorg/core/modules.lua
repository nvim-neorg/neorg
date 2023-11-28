-- TODO: What goes below this line until the next notice used to belong to modules.base
-- We need to find a way to make these constructors easier to maintain and more efficient

--[[
--    BASE FILE FOR MODULES
--    This file contains the base module implementation
--]]

local callbacks = require("neorg.core.callbacks")
local config = require("neorg.core.config")
local log = require("neorg.core.log")
local utils = require("neorg.core.utils")

local modules = {}

--- Returns a new Neorg module, exposing all the necessary function and variables
---@param name string #The name of the new module. Make sure this is unique. The recommended naming convention is category.module_name or category.subcategory.module_name
---@param imports? string[] #A list of imports to attach to the module. Import data is requestable via `module.required`. Use paths relative to the current module.
function modules.create(name, imports)
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
        path = "modules.core.default.module",

        -- A convenience table to place all of your private variables that you don't want to expose here.
        private = {},

        -- Every module can expose any set of information it sees fit through the public field
        -- All functions and variables declared in this table will be visible to any other module loaded
        public = {
            -- Current Norg version that this module supports.
            -- Your module will use this version if not specified, but you can override it.
            -- Overriding it will mean that your module is only compatible with the overriden Norg revision.
            -- E.g: setting version = "1.0.0" will mean that your module requires Norg 1.0.0+ to operate
            version = config.norg_version,
        },

        -- Configuration for the module
        config = {
            private = { -- Private module config, cannot be changed by other modules or by the user
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

            if not modules.load_module(fullpath) then
                log.error("Unable to load import '" .. fullpath .. "'! An error occured (see traceback below):")
                assert(false) -- Halt execution, no recovering from this error...
            end

            new_module.imported[fullpath] = modules.loaded_modules[fullpath]
        end
    end

    if name then
        new_module.name = name
        new_module.path = "modules." .. name
    end

    return new_module
end

--- Constructs a metamodule from a list of submodules. Metamodules are modules that can autoload batches of modules at once.
---@param name string #The name of the new metamodule. Make sure this is unique. The recommended naming convention is category.module_name or category.subcategory.module_name
-- @Param  ... (varargs) - a list of module names to load.
function modules.create_meta(name, ...)
    local module = modules.create(name)

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
            modules.load_module(mod)
        end
    end

    return module
end

-- TODO: What goes below this line until the next notice used to belong to modules
-- We need to find a way to make these functions easier to maintain

--[[
--    NEORG MODULE MANAGER
--    This file is responsible for loading, calling and managing modules
--    Modules are internal mini-programs that execute on certain events, they build the foundation of Neorg itself.
--]]

--[[
--    The reason we do not just call this variable modules.loaded_modules.count is because
--    someone could make a module called "count" and override the variable, causing bugs.
--]]
modules.loaded_module_count = 0

--- The table of currently loaded modules
modules.loaded_modules = {}

--- Loads and enables a module
-- Loads a specified module. If the module subscribes to any events then they will be activated too.
---@param module table #The actual module to load
---@return boolean #Whether the module successfully loaded
function modules.load_module_from_table(module)
    log.info("Loading module with name", module.name)

    -- If our module is already loaded don't try loading it again
    if modules.loaded_modules[module.name] then
        log.trace("Module", module.name, "already loaded. Omitting...")
        return true
    end

    -- Invoke the setup function. This function returns whether or not the loading of the module was successful and some metadata.
    local loaded_module = module.setup and module.setup()
        or {
            success = true,
            replaces = {},
            replace_merge = false,
            requires = {},
            wants = {},
        }

    -- We do not expect module.setup() to ever return nil, that's why this check is in place
    if not loaded_module then
        log.error(
            "Module",
            module.name,
            "does not handle module loading correctly; module.setup() returned nil. Omitting..."
        )
        return false
    end

    -- A part of the table returned by module.setup() tells us whether or not the module initialization was successful
    if loaded_module.success == false then
        log.trace("Module", module.name, "did not load properly.")
        return false
    end

    --[[
    --    This small snippet of code creates a copy of an already loaded module with the same name.
    --    If the module wants to replace an already loaded module then we need to create a deepcopy of that old module
    --    in order to stop it from getting overwritten.
    --]]
    local module_to_replace

    -- If the return value of module.setup() tells us to hotswap with another module then cache the module we want to replace with
    if loaded_module.replaces and loaded_module.replaces ~= "" then
        module_to_replace = vim.deepcopy(modules.loaded_modules[loaded_module.replaces])
    end

    -- Add the module into the list of loaded modules
    -- The reason we do this here is so other modules don't recursively require each other in the dependency loading loop below
    modules.loaded_modules[module.name] = module

    -- If the module "wants" any other modules then verify they are loaded
    if loaded_module.wants and not vim.tbl_isempty(loaded_module.wants) then
        log.info("Module", module.name, "wants certain modules. Ensuring they are loaded...")

        -- Loop through each dependency and ensure it's loaded
        for _, required_module in ipairs(loaded_module.wants) do
            log.trace("Verifying", required_module)

            -- This would've always returned false had we not added the current module to the loaded module list earlier above
            if not modules.is_module_loaded(required_module) then
                if config.user_config[required_module] then
                    log.trace(
                        "Wanted module",
                        required_module,
                        "isn't loaded but can be as it's defined in the user's config. Loading..."
                    )

                    if not modules.load_module(required_module) then
                        log.error(
                            "Unable to load wanted module for",
                            loaded_module.name,
                            "- the module didn't load successfully"
                        )

                        -- Make sure to clean up after ourselves if the module failed to load
                        modules.loaded_modules[module.name] = nil
                        return false
                    end
                else
                    log.error(
                        ("Unable to load module %s, wanted dependency %s was not satisfied. Be sure to load the module and its appropriate config too!"):format(
                            module.name,
                            required_module
                        )
                    )

                    -- Make sure to clean up after ourselves if the module failed to load
                    modules.loaded_modules[module.name] = nil
                    return false
                end
            end

            -- Create a reference to the dependency's public table
            module.required[required_module] = modules.loaded_modules[required_module].public
        end
    end

    -- If any dependencies have been defined, handle them
    if loaded_module.requires and vim.tbl_count(loaded_module.requires) > 0 then
        log.info("Module", module.name, "has dependencies. Loading dependencies first...")

        -- Loop through each dependency and load it one by one
        for _, required_module in pairs(loaded_module.requires) do
            log.trace("Loading submodule", required_module)

            -- This would've always returned false had we not added the current module to the loaded module list earlier above
            if not modules.is_module_loaded(required_module) then
                if not modules.load_module(required_module) then
                    log.error(
                        ("Unable to load module %s, required dependency %s did not load successfully"):format(
                            module.name,
                            required_module
                        )
                    )

                    -- Make sure to clean up after ourselves if the module failed to load
                    modules.loaded_modules[module.name] = nil
                    return false
                end
            else
                log.trace("Module", required_module, "already loaded, skipping...")
            end

            -- Create a reference to the dependency's public table
            module.required[required_module] = modules.loaded_modules[required_module].public
        end
    end

    -- After loading all our dependencies, see if we need to hotswap another module with ourselves
    if module_to_replace then
        -- Make sure the names of both modules match
        module.name = module_to_replace.name

        -- Whenever a module gets hotswapped, a special flag is set inside the module in order to signalize that it has been hotswapped before
        -- If this flag has already been set before, then throw an error - there is no way for us to know which hotswapped module should take priority.
        if module_to_replace.replaced then
            log.error(
                ("Unable to replace module %s - module replacement clashing detected. This error triggers when a module tries to be replaced more than two times - neorg doesn't know which replacement to prioritize."):format(
                    module_to_replace.name
                )
            )

            -- Make sure to clean up after ourselves if the module failed to load
            modules.loaded_modules[module.name] = nil

            return false
        end

        -- If the replace_merge flag is set to true in the setup() return value then recursively merge the data from the
        -- previous module into our new one. This allows for practically seamless hotswapping, as it allows you to retain the data
        -- of the previous module.
        if loaded_module.replace_merge then
            module = vim.tbl_deep_extend("force", module, {
                private = module_to_replace.private,
                config = module_to_replace.config,
                public = module_to_replace.public,
                events = module_to_replace.events,
            })
        end

        -- Set the special module.replaced flag to let everyone know we've been hotswapped before
        module.replaced = true
    end

    log.info("Successfully loaded module", module.name)

    -- Keep track of the number of loaded modules
    modules.loaded_module_count = modules.loaded_module_count + 1

    -- NOTE(vhyrro): Left here for debugging.
    -- Maybe make controllable with a switch in the future.
    -- local start = vim.loop.hrtime()

    -- Call the load function
    if module.load then
        module.load()
    end

    -- local msg = ("%fms"):format((vim.loop.hrtime() - start) / 1e6)
    -- vim.notify(msg .. " " .. module.name)

    modules.broadcast_event({
        type = "core.module_loaded",
        split_type = { "core", "module_loaded" },
        filename = "",
        filehead = "",
        cursor_position = { 0, 0 },
        referrer = "core",
        line_content = "",
        content = module,
        broadcast = true,
    })

    return true
end

--- Unlike `load_module_from_table()`, which loads a module from memory, `load_module()` tries to find the corresponding module file on disk and loads it into memory.
-- If the module cannot not be found, attempt to load it off of github (unimplemented). This function also applies user-defined config and keymaps to the modules themselves.
-- This is the recommended way of loading modules - `load_module_from_table()` should only really be used by neorg itself.
---@param module_name string #A path to a module on disk. A path seperator in neorg is '.', not '/'
---@param cfg table? #A config that reflects the structure of `neorg.config.user_config.load["module.name"].config`
---@return boolean #Whether the module was successfully loaded
function modules.load_module(module_name, cfg)
    -- Don't bother loading the module from disk if it's already loaded
    if modules.is_module_loaded(module_name) then
        return true
    end

    -- Attempt to require the module, does not throw an error if the module doesn't exist
    local exists, module = pcall(require, "neorg.modules." .. module_name .. ".module")

    -- If the module doesn't exist then return false
    if not exists then
        local fallback_exists, fallback_module = pcall(require, "neorg.modules." .. module_name)

        if not fallback_exists then
            log.error("Unable to load module", module_name, "-", module)
            return false
        end

        module = fallback_module
    end

    -- If the module is nil for some reason return false
    if not module then
        log.error(
            "Unable to load module",
            module_name,
            "- loaded file returned nil. Be sure to return the table created by modules.create() at the end of your module.lua file!"
        )
        return false
    end

    -- If the value of `module` is strictly true then it means the required file returned nothing
    -- We obviously can't do anything meaningful with that!
    if module == true then
        log.error(
            "An error has occurred when loading",
            module_name,
            "- loaded file didn't return anything meaningful. Be sure to return the table created by modules.create() at the end of your module.lua file!"
        )
        return false
    end

    -- Load the user-defined config
    if cfg and not vim.tbl_isempty(cfg) then
        module.config.custom = cfg
        module.config.public = vim.tbl_deep_extend("force", module.config.public, cfg)
    else
        module.config.custom = config.modules[module_name]
        module.config.public = vim.tbl_deep_extend("force", module.config.public, module.config.custom or {})
    end

    -- Pass execution onto load_module_from_table() and let it handle the rest
    return modules.load_module_from_table(module)
end

--- Has the same principle of operation as load_module_from_table(), except it then sets up the parent module's "required" table, allowing the parent to access the child as if it were a dependency.
---@param module table #A valid table as returned by modules.create()
---@param parent_module string|table #If a string, then the parent is searched for in the loaded modules. If a table, then the module is treated as a valid module as returned by modules.create()
function modules.load_module_as_dependency_from_table(module, parent_module)
    if modules.load_module_from_table(module) then
        if type(parent_module) == "string" then
            modules.loaded_modules[parent_module].required[module.name] = module.public
        elseif type(parent_module) == "table" then
            parent_module.required[module.name] = module.public
        end
    end
end

--- Normally loads a module, but then sets up the parent module's "required" table, allowing the parent module to access the child as if it were a dependency.
---@param module_name string #A path to a module on disk. A path seperator in neorg is '.', not '/'
---@param parent_module string #The name of the parent module. This is the module which the dependency will be attached to.
---@param cfg table #A config that reflects the structure of neorg.config.user_config.load["module.name"].config
function modules.load_module_as_dependency(module_name, parent_module, cfg)
    if modules.load_module(module_name, cfg) and modules.is_module_loaded(parent_module) then
        modules.loaded_modules[parent_module].required[module_name] = modules.get_module_config(module_name)
    end
end

--- Retrieves the public API exposed by the module
---@param module_name string #The name of the module to retrieve
function modules.get_module(module_name)
    if not modules.is_module_loaded(module_name) then
        log.trace("Attempt to get module with name", module_name, "failed - module is not loaded.")
        return
    end

    return modules.loaded_modules[module_name].public
end

--- Returns the module.config.public table if the module is loaded
---@param module_name string #The name of the module to retrieve (module must be loaded)
function modules.get_module_config(module_name)
    if not modules.is_module_loaded(module_name) then
        log.trace("Attempt to get module config with name", module_name, "failed - module is not loaded.")
        return
    end

    return modules.loaded_modules[module_name].config.public
end

--- Returns true if module with name module_name is loaded, false otherwise
---@param module_name string #The name of an arbitrary module
function modules.is_module_loaded(module_name)
    return modules.loaded_modules[module_name] ~= nil
end

--- Reads the module's public table and looks for a version variable, then converts it from a string into a table, like so: { major = <number>, minor = <number>, patch = <number> }
---@param module_name string #The name of a valid, loaded module.
-- @Return struct | nil (if any error occurs)
function modules.get_module_version(module_name)
    -- If the module isn't loaded then don't bother retrieving its version
    if not modules.is_module_loaded(module_name) then
        log.trace("Attempt to get module version with name", module_name, "failed - module is not loaded.")
        return
    end

    -- Grab the version of the module
    local version = modules.get_module(module_name).version

    -- If it can't be found then error out
    if not version then
        log.trace("Attempt to get module version with name", module_name, "failed - version variable not present.")
        return
    end

    return utils.parse_version_string(version)
end

--- Executes `callback` once `module` is a valid and loaded module, else the callback gets instantly executed.
---@param module_name string #The name of the module to listen for.
---@param callback fun(module_public_table: table) #The callback to execute.
function modules.await(module_name, callback)
    if modules.is_module_loaded(module_name) then
        callback(assert(modules.get_module(module_name)))
        return
    end

    callbacks.on_event("core.module_loaded", function(_, module)
        callback(module.public)
    end, function(event)
        return event.content.name == module_name ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
    end)
end

-- TODO: What goes below this line until the next notice used to belong to modules
-- We need to find a way to make these functions easier to maintain

--[[
--    NEORG EVENT FILE
--    This file is responsible for dealing with event handling and broadcasting.
--    All modules that subscribe to an event will receive it once it is triggered.
--]]

--- The working of this function is best illustrated with an example:
--        If type == 'core.some_plugin.events.my_event', this function will return { 'core.some_plugin', 'my_event' }
---@param type string #The full path of a module event
function modules.split_event_type(type)
    local start_str, end_str = type:find("%.events%.")

    local split_event_type = { type:sub(0, start_str - 1), type:sub(end_str + 1) }

    if #split_event_type ~= 2 then
        log.warn("Invalid type name:", type)
        return
    end

    return split_event_type
end

--- Returns an event template defined in module.events.defined
---@param module table #A reference to the module invoking the function
---@param type string #A full path to a valid event type (e.g. 'core.module.events.some_event')
function modules.get_event_template(module, type)
    -- You can't get the event template of a type if the type isn't loaded
    if not modules.is_module_loaded(module.name) then
        log.info("Unable to get event of type", type, "with module", module.name)
        return
    end

    -- Split the event type into two
    local split_type = modules.split_event_type(type)

    if not split_type then
        log.warn("Unable to get event template for event", type, "and module", module.name)
        return
    end

    log.trace("Returning", split_type[2], "for module", split_type[1])

    -- Return the defined event from the specific module
    return modules.loaded_modules[module.name].events.defined[split_type[2]]
end

--- Creates a deep copy of the modules.base_event event and returns it with a custom type and referrer
---@param module table #A reference to the module invoking the function
---@param name string #A relative path to a valid event template
function modules.define_event(module, name)
    -- Create a copy of the base event and override the values with ones specified by the user

    local new_event = {
        type = "core.base_event",
        split_type = {},
        content = nil,
        referrer = nil,
        broadcast = true,

        cursor_position = {},
        filename = "",
        filehead = "",
        line_content = "",
        buffer = 0,
        window = 0,
        mode = "",
    }

    if name then
        new_event.type = module.name .. ".events." .. name
    end

    new_event.referrer = module.name

    return new_event
end

--- Returns a copy of the event template provided by a module
---@param module table #A reference to the module invoking the function
---@param type string #A full path to a valid event type (e.g. 'core.module.events.some_event')
---@param content any #The content of the event, can be anything from a string to a table to whatever you please
---@param ev? table the original event data
---@return table #New event
function modules.create_event(module, type, content, ev)
    -- Get the module that contains the event
    local module_name = modules.split_event_type(type)[1]

    -- Retrieve the template from module.events.defined
    local event_template = modules.get_event_template(modules.loaded_modules[module_name] or { name = "" }, type)

    if not event_template then
        log.warn("Unable to create event of type", type, ". Returning nil...")
        return ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
    end

    -- Make a deep copy here - we don't want to override the actual base table!
    local new_event = vim.deepcopy(event_template)

    new_event.type = type
    new_event.content = content
    new_event.referrer = module.name

    -- Override all the important values
    new_event.split_type = modules.split_event_type(type)
    new_event.filename = vim.fn.expand("%:t")
    new_event.filehead = vim.fn.expand("%:p:h")
    local bufid = ev and ev.buf or vim.api.nvim_get_current_buf()
    local winid = vim.fn.bufwinid(bufid)
    new_event.cursor_position = vim.api.nvim_win_get_cursor(winid)
    local row_1b = new_event.cursor_position[1]
    new_event.line_content = vim.api.nvim_buf_get_lines(bufid, row_1b-1, row_1b, true)[1]
    new_event.referrer = module.name
    new_event.broadcast = true
    new_event.buffer = bufid
    new_event.window = winid
    new_event.mode = vim.api.nvim_get_mode().mode

    return new_event
end

--- Sends an event to all subscribed modules. The event contains the filename, filehead, cursor position and line content as a bonus.
---@param event table #An event, usually created by modules.create_event()
---@param callback function? #A callback to be invoked after all events have been asynchronously broadcast
function modules.broadcast_event(event, callback)
    -- Broadcast the event to all modules
    if not event.split_type then
        log.error("Unable to broadcast event of type", event.type, "- invalid event name")
        return
    end

    -- Let the callback handler know of the event
    callbacks.handle_callbacks(event)

    -- Loop through all the modules
    for _, current_module in pairs(modules.loaded_modules) do
        -- If the current module has any subscribed events and if it has a subscription bound to the event's module name then
        if current_module.events.subscribed and current_module.events.subscribed[event.split_type[1]] then
            -- Check whether we are subscribed to the event type
            local evt = current_module.events.subscribed[event.split_type[1]][event.split_type[2]]

            if evt ~= nil and evt == true then
                -- Run the on_event() for that module
                current_module.on_event(event)
            end
        end
    end

    -- Because the broadcasting of events is async we allow the event broadcaster to provide a callback
    -- TODO: deprecate
    if callback then
        callback()
    end
end

--- Instead of broadcasting to all loaded modules, send_event() only sends to one module
---@param recipient string #The name of a loaded module that will be the recipient of the event
---@param event table #An event, usually created by modules.create_event()
function modules.send_event(recipient, event)
    -- If the recipient is not loaded then there's no reason to send an event to it
    if not modules.is_module_loaded(recipient) then
        log.warn("Unable to send event to module", recipient, "- the module is not loaded.")
        return
    end

    -- Set the broadcast variable to false since we're not invoking broadcast_event()
    event.broadcast = false

    -- Let the callback handler know of the event
    callbacks.handle_callbacks(event)

    -- Get the recipient module and check whether it's subscribed to our event
    local mod = modules.loaded_modules[recipient]

    if mod.events.subscribed and mod.events.subscribed[event.split_type[1]] then
        local evt = mod.events.subscribed[event.split_type[1]][event.split_type[2]]

        -- If it is then trigger the module's on_event() function
        if evt ~= nil and evt == true then
            mod.on_event(event)
        end
    end
end

return modules
