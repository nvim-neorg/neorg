--[[
--    NEORG MODULE MANAGER
--    This file is responsible for loading, calling and managing modules
--    Modules are internal mini-programs that execute on certain events, they build the foundation of Neorg itself.
--]]

-- Include the global logger instance
local log = require("neorg.external.log")

require("neorg.modules.base")

--[[
--    The reason we do not just call this variable neorg.modules.loaded_modules.count is because
--    someone could make a module called "count" and override the variable, causing bugs.
--]]
neorg.modules.loaded_module_count = 0

--- The table of currently loaded modules
neorg.modules.loaded_modules = {}

--- Loads and enables a module
-- Loads a specified module. If the module subscribes to any events then they will be activated too.
---@param module table #The actual module to load
---@param parent string? #The name of a potential parent of the module
---@return boolean #Whether the module successfully loaded
function neorg.modules.load_module_from_table(module, parent)
    log.info("Loading module with name", module.name)

    -- If our module is already loaded don't try loading it again
    if neorg.modules.loaded_modules[module.name] then
        log.trace("Module", module.name, "already loaded. Omitting...")
        return true
    end

    if parent then
        module = module:from(neorg.modules.loaded_modules[parent])
    end

    -- Invoke the setup function. This function returns whether or not the loading of the module was successful and some metadata.
    local loaded_module = module.setup and module.setup()
        or {
            success = true,
            replaces = {},
            replace_merge = false,
            requires = {},
            wants = {},
            imports = {},
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
        module_to_replace = vim.deepcopy(neorg.modules.loaded_modules[loaded_module.replaces])
    end

    -- Add the module into the list of loaded modules
    -- The reason we do this here is so other modules don't recursively require each other in the dependency loading loop below
    neorg.modules.loaded_modules[module.name] = module

    -- If the module "wants" any other modules then verify they are loaded
    if loaded_module.wants and not vim.tbl_isempty(loaded_module.wants) then
        log.info("Module", module.name, "wants certain modules. Ensuring they are loaded...")

        -- Loop through each dependency and ensure it's loaded
        for _, required_module in ipairs(loaded_module.wants) do
            log.trace("Verifying", required_module)

            -- This would've always returned false had we not added the current module to the loaded module list earlier above
            if not neorg.modules.is_module_loaded(required_module) then
                if neorg.configuration.user_configuration[required_module] then
                    log.trace(
                        "Wanted module",
                        required_module,
                        "isn't loaded but can be as it's defined in the user's config. Loading..."
                    )

                    if not neorg.modules.load_module(required_module) then
                        log.error(
                            "Unable to load wanted module for",
                            loaded_module.name,
                            "- the module didn't load successfully"
                        )

                        -- Make sure to clean up after ourselves if the module failed to load
                        neorg.modules.loaded_modules[module.name] = nil
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
                    neorg.modules.loaded_modules[module.name] = nil
                    return false
                end
            end

            -- Create a reference to the dependency's public table
            module.required[required_module] = neorg.modules.loaded_modules[required_module].public
        end
    end

    -- If any dependencies have been defined, handle them
    if loaded_module.requires and vim.tbl_count(loaded_module.requires) > 0 then
        log.info("Module", module.name, "has dependencies. Loading dependencies first...")

        -- Loop through each dependency and load it one by one
        for _, required_module in pairs(loaded_module.requires) do
            log.trace("Loading submodule", required_module)

            -- This would've always returned false had we not added the current module to the loaded module list earlier above
            if not neorg.modules.is_module_loaded(required_module) then
                if not neorg.modules.load_module(required_module) then
                    log.error(
                        ("Unable to load module %s, required dependency %s did not load successfully"):format(
                            module.name,
                            required_module
                        )
                    )

                    -- Make sure to clean up after ourselves if the module failed to load
                    neorg.modules.loaded_modules[module.name] = nil
                    return false
                end
            else
                log.trace("Module", required_module, "already loaded, skipping...")
            end

            -- Create a reference to the dependency's public table
            module.required[required_module] = neorg.modules.loaded_modules[required_module].public
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
            neorg.modules.loaded_modules[module.name] = nil

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

    if loaded_module.imports and not vim.tbl_isempty(loaded_module.imports) then
        log.info("Module", module.name, "has imports. Including them...")

        for _, import in ipairs(loaded_module.imports) do
            if not neorg.modules.load_module(module.name .. "." .. import, module.name) then
                log.error(
                    "Unable to load",
                    module.name,
                    "- the module specified an import (" .. import .. ") but that import could not be found under",
                    "neorg.modules." .. module.name .. "." .. import
                )
                return false
            end

            module = module:from(neorg.modules.loaded_modules[module.name .. "." .. import], "keep")
        end
    end

    log.info("Successfully loaded module", module.name)

    -- Keep track of the number of loaded modules
    neorg.modules.loaded_module_count = neorg.modules.loaded_module_count + 1

    -- NOTE(vhyrro): Left here for debugging.
    -- Maybe make controllable with a switch in the future.
    -- local start = vim.loop.hrtime()

    -- Call the load function
    if module.load then
        module.load()
    end

    -- local msg = ("%fms"):format((vim.loop.hrtime() - start) / 1e6)
    -- vim.notify(msg .. " " .. module.name)

    neorg.events.broadcast_event({
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
-- If the module cannot not be found, attempt to load it off of github (unimplemented). This function also applies user-defined configurations and keymaps to the modules themselves.
-- This is the recommended way of loading modules - `load_module_from_table()` should only really be used by neorg itself.
---@param module_name string #A path to a module on disk. A path seperator in neorg is '.', not '/'
---@param parent string? #The name of a potential parent of the module
---@param config table? #A configuration that reflects the structure of `neorg.configuration.user_configuration.load["module.name"].config`
---@return boolean #Whether the module was successfully loaded
function neorg.modules.load_module(module_name, parent, config)
    -- Don't bother loading the module from disk if it's already loaded
    if neorg.modules.is_module_loaded(module_name) then
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
            "- loaded file returned nil. Be sure to return the table created by neorg.modules.create() at the end of your module.lua file!"
        )
        return false
    end

    -- If the value of `module` is strictly true then it means the required file returned nothing
    -- We obviously can't do anything meaningful with that!
    if module == true then
        log.error(
            "An error has occurred when loading",
            module_name,
            "- loaded file didn't return anything meaningful. Be sure to return the table created by neorg.modules.create() at the end of your module.lua file!"
        )
        return false
    end

    -- Load the user-defined configuration
    if config and not vim.tbl_isempty(config) then
        module.config.custom = config
        module.config.public = vim.tbl_deep_extend("force", module.config.public, config)
    else
        module.config.public =
            vim.tbl_deep_extend("force", module.config.public, require("neorg.config").modules[module_name] or {})
    end

    -- Pass execution onto load_module_from_table() and let it handle the rest
    return neorg.modules.load_module_from_table(module, parent)
end

--- Has the same principle of operation as load_module_from_table(), except it then sets up the parent module's "required" table, allowing the parent to access the child as if it were a dependency.
---@param module table #A valid table as returned by neorg.modules.create()
---@param parent_module string|table #If a string, then the parent is searched for in the loaded modules. If a table, then the module is treated as a valid module as returned by neorg.modules.create()
function neorg.modules.load_module_as_dependency_from_table(module, parent_module)
    if neorg.modules.load_module_from_table(module) then
        if type(parent_module) == "string" then
            neorg.modules.loaded_modules[parent_module].required[module.name] = module.public
        elseif type(parent_module) == "table" then
            parent_module.required[module.name] = module.public
        end
    end
end

--- Normally loads a module, but then sets up the parent module's "required" table, allowing the parent module to access the child as if it were a dependency.
---@param module_name string #A path to a module on disk. A path seperator in neorg is '.', not '/'
---@param parent_module string #The name of the parent module. This is the module which the dependency will be attached to.
---@param config table #A configuration that reflects the structure of neorg.configuration.user_configuration.load["module.name"].config
function neorg.modules.load_module_as_dependency(module_name, parent_module, config)
    if neorg.modules.load_module(module_name, nil, config) and neorg.modules.is_module_loaded(parent_module) then
        neorg.modules.loaded_modules[parent_module].required[module_name] = neorg.modules.get_module_config(module_name)
    end
end

--- Retrieves the public API exposed by the module
---@param module_name string #The name of the module to retrieve
function neorg.modules.get_module(module_name)
    if not neorg.modules.is_module_loaded(module_name) then
        log.trace("Attempt to get module with name", module_name, "failed - module is not loaded.")
        return
    end

    return neorg.modules.loaded_modules[module_name].public
end

--- Returns the module.config.public table if the module is loaded
---@param module_name string #The name of the module to retrieve (module must be loaded)
function neorg.modules.get_module_config(module_name)
    if not neorg.modules.is_module_loaded(module_name) then
        log.trace("Attempt to get module configuration with name", module_name, "failed - module is not loaded.")
        return
    end

    return neorg.modules.loaded_modules[module_name].config.public
end

--- Returns true if module with name module_name is loaded, false otherwise
---@param module_name string #The name of an arbitrary module
function neorg.modules.is_module_loaded(module_name)
    return neorg.modules.loaded_modules[module_name] ~= nil
end

--- Reads the module's public table and looks for a version variable, then converts it from a string into a table, like so: { major = <number>, minor = <number>, patch = <number> }
---@param module_name string #The name of a valid, loaded module.
-- @Return struct | nil (if any error occurs)
function neorg.modules.get_module_version(module_name)
    -- If the module isn't loaded then don't bother retrieving its version
    if not neorg.modules.is_module_loaded(module_name) then
        log.trace("Attempt to get module version with name", module_name, "failed - module is not loaded.")
        return
    end

    -- Grab the version of the module
    local version = neorg.modules.get_module(module_name).version

    -- If it can't be found then error out
    if not version then
        log.trace("Attempt to get module version with name", module_name, "failed - version variable not present.")
        return
    end

    return neorg.utils.parse_version_string(version)
end

--- Executes `callback` once `module` is a valid and loaded module, else the callback gets instantly executed.
---@param module_name string #The name of the module to listen for.
---@param callback fun(public_module_table) #The callback to execute.
function neorg.modules.await(module_name, callback)
    if neorg.modules.is_module_loaded(module_name) then
        callback(neorg.modules.get_module(module_name))
        return
    end

    neorg.callbacks.on_event("core.module_loaded", function(_, module)
        callback(module.public)
    end, function(event)
        return event.content.name == module_name
    end)
end
