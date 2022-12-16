--[[
    File: User-Keybinds
    Title: The Keybinds Module
    Summary: Module for managing keybindings with Neorg mode support.
    ---

### Disabling Default Keybinds
By default when you load the `core.keybinds` module all keybinds will be enabled.
If you want to change this, be sure to set `default_keybinds` to `false`:
```lua
["core.keybinds"] = {
    config = {
        default_keybinds = false,
    }
}
```

### Setting Up a Keybind Hook
Want to change some keybinds? You can set up a function that will allow you to tweak
every keybind bit by bit.

```lua
["core.keybinds"] = {
    config = {
        hook = function(keybinds)
            -- Unmaps any Neorg key from the `norg` mode
            keybinds.unmap("norg", "n", "gtd")

            -- Binds the `gtd` key in `norg` mode to execute `:echo 'Hello'`
            keybinds.map("norg", "n", "gtd", "<cmd>echo 'Hello!'<CR>")

            -- Remap unbinds the current key then rebinds it to have a different action
            -- associated with it.
            -- The following is the equivalent of the `unmap` and `map` calls you saw above:
            keybinds.remap("norg", "n", "gtd", "<cmd>echo 'Hello!'<CR>")

            -- Sometimes you may simply want to rebind the Neorg action something is bound to
            -- versus remapping the entire keybind. This remap is essentially the same as if you
            -- did `keybinds.remap("norg", "n", "<C-Space>, "<cmd>Neorg keybind norg core.norg.qol.todo_items.todo.task_done<CR>")
            keybinds.remap_event("norg", "n", "<C-Space>", "core.norg.qol.todo_items.todo.task_done")

            -- Want to move one keybind into the other? `remap_key` moves the data of the
            -- first keybind to the second keybind, then unbinds the first keybind.
            keybinds.remap_key("norg", "n", "<C-Space>", "<Leader>t")
        end,
    }
}
```
--]]

require("neorg.modules.base")
require("neorg.modules")

local module = neorg.modules.create("core.keybinds")

local log = require("neorg.external.log")

module.setup = function()
    return {
        success = true,
        requires = { "core.neorgcmd", "core.mode", "core.autocommands" },
        imports = { "keybinds" },
    }
end

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("BufLeave")

    if module.config.public.hook then
        neorg.callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybinds)
            module.config.public.hook(keybinds)
        end)
    end
end

module.config.public = {
    -- Use the default keybinds provided in https://github.com/nvim-neorg/neorg/blob/main/lua/neorg/modules/core/keybinds/keybinds.lua
    default_keybinds = true,

    -- Prefix for some Neorg keybinds
    neorg_leader = "<LocalLeader>",

    -- Function to be invoked that allows the user to change their keybinds
    hook = nil,

    -- The keybind preset to use
    keybind_preset = "neorg",

    -- An array of functions, each one corresponding to a separate preset
    keybind_presets = {},
}

---@class core.keybinds
module.public = {

    -- Define neorgcmd autocompletions and commands
    neorg_commands = {
        keybind = {
            min_args = 2,
            name = "core.keybinds.trigger",

            complete = {
                {},
                {},
            },
        },
    },

    version = "0.0.9",

    -- Adds a new keybind to the database of known keybinds
    -- @param module_name string #the name of the module that owns the keybind. Make sure it's an absolute path.
    -- @param name string  #the name of the keybind. The module_name will be prepended to this string to form a unique name.
    register_keybind = function(module_name, name)
        -- Create the full keybind name
        local keybind_name = module_name .. "." .. name

        -- If that keybind is not defined yet then define it
        if not module.events.defined[keybind_name] then
            module.events.defined[keybind_name] = neorg.events.define(module, keybind_name)

            -- Define autocompletion for core.neorgcmd
            table.insert(module.public.neorg_commands.keybind.complete[2], keybind_name)
        end

        -- Update core.neorgcmd's internal tables
        module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
    end,

    --- Like register_keybind(), except registers a batch of them
    ---@param module_name string #The name of the module that owns the keybind. Make sure it's an absolute path.
    ---@param names #list of strings - a list of strings detailing names of the keybinds. The module_name will be prepended to each one to form a unique name.
    register_keybinds = function(module_name, names)
        -- Loop through each name from the names argument
        for _, name in ipairs(names) do
            -- Create the full keybind name
            local keybind_name = module_name .. "." .. name

            -- If that keybind is not defined yet then define it
            if not module.events.defined[keybind_name] then
                module.events.defined[keybind_name] = neorg.events.define(module, keybind_name)

                -- Define autocompletion for core.neorgcmd
                table.insert(module.public.neorg_commands.keybind.complete[2], keybind_name)
            end
        end

        -- Update core.neorgcmd's internal tables
        module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
    end,

    bind_all = function(buf, action, for_mode)
        local current_mode = for_mode or module.required["core.mode"].get_mode()

        -- Keep track of the keys the user may want to bind
        local bound_keys = {}

        -- Broadcast the enable_keybinds event to any user that might have registered a User Callback for it
        local payload

        payload = {

            --- Maps a key to a specific Neorg mode
            ---@param neorg_mode string #The Neorg mode to bind to
            ---@param mode string #The Neovim mode to bind to, e.g. `n` or `i` etc.
            ---@param key string #The lhs value from `:h vim.keymap.set`
            ---@param command string|function #The rhs value from `:h vim.keymap.set`
            ---@param opts table #The table value from `:h vim.keymap.set`
            map = function(neorg_mode, mode, key, command, opts)
                if neorg_mode ~= "all" and current_mode ~= neorg_mode then
                    return
                end

                bound_keys[neorg_mode] = bound_keys[neorg_mode] or {}
                bound_keys[neorg_mode][mode] = bound_keys[neorg_mode][mode] or {}
                bound_keys[neorg_mode][mode][key] = bound_keys[neorg_mode][mode][key] or {}

                bound_keys[neorg_mode][mode][key] = {
                    command = command,
                    opts = opts,
                }
            end,

            --- Maps a key to a specific Neorg keybind.
            --  `map()` binds to any rhs value, whilst `map_event()` is essentially a wrapper
            --  for <cmd>Neorg keybind `neorg_mode` `expr`<CR>
            ---@param neorg_mode string #The Neorg mode to bind to
            ---@param mode string #The Neovim mode to bind to, e.g. `n` or `i` etc.
            ---@param key string #The lhs value from `:h vim.keymap.set`
            ---@param expr string #The Neorg event to bind to (e.g. `core.norg.dirman.new.note`)
            ---@param opts table #The table value from `:h vim.keymap.set`
            map_event = function(neorg_mode, mode, key, expr, opts)
                payload.map(neorg_mode, mode, key, "<cmd>Neorg keybind " .. neorg_mode .. " " .. expr .. "<CR>", opts)
            end,

            --- Unmaps any keybind from any Neorg mode
            ---@param neorg_mode string #The Neorg mode to remove the key from
            ---@param mode string #The target Neovim mode
            ---@param key string #The key itself to unmap
            unmap = function(neorg_mode, mode, key)
                if neorg_mode == "all" then
                    for _, norg_mode in ipairs(module.required["core.mode"].get_modes()) do
                        payload.unmap(norg_mode, mode, key)
                    end
                end

                bound_keys[neorg_mode] = bound_keys[neorg_mode] or {}
                bound_keys[neorg_mode][mode] = bound_keys[neorg_mode][mode] or {}

                bound_keys[neorg_mode][mode][key] = bound_keys[neorg_mode][mode][key] and nil
            end,

            remap = function(neorg_mode, mode, key, new_rhs)
                if neorg_mode ~= "all" and current_mode ~= neorg_mode then
                    return
                end

                bound_keys[neorg_mode] = bound_keys[neorg_mode] or {}
                bound_keys[neorg_mode][mode] = bound_keys[neorg_mode][mode] or {}
                bound_keys[neorg_mode][mode][key] = bound_keys[neorg_mode][mode][key] or {}

                local opts = bound_keys[neorg_mode][mode][key].opts

                payload.map(neorg_mode, mode, key, new_rhs, opts)
            end,

            remap_event = function(neorg_mode, mode, key, new_event)
                if neorg_mode ~= "all" and current_mode ~= neorg_mode then
                    return
                end

                bound_keys[neorg_mode] = bound_keys[neorg_mode] or {}
                bound_keys[neorg_mode][mode] = bound_keys[neorg_mode][mode] or {}
                bound_keys[neorg_mode][mode][key] = bound_keys[neorg_mode][mode][key] or {}

                local opts = bound_keys[neorg_mode][mode][key].opts

                payload.map(
                    neorg_mode,
                    mode,
                    key,
                    "<cmd>Neorg keybind " .. neorg_mode .. " " .. new_event .. "<CR>",
                    opts
                )
            end,

            remap_key = function(neorg_mode, mode, old_key, new_key)
                if neorg_mode ~= "all" and current_mode ~= neorg_mode then
                    return
                end

                bound_keys[neorg_mode] = bound_keys[neorg_mode] or {}
                bound_keys[neorg_mode][mode] = bound_keys[neorg_mode][mode] or {}
                bound_keys[neorg_mode][mode][old_key] = bound_keys[neorg_mode][mode][old_key] or {}

                local command = bound_keys[neorg_mode][mode][old_key].command
                local opts = bound_keys[neorg_mode][mode][old_key].opts

                payload.unmap(neorg_mode, mode, old_key)
                payload.map(neorg_mode, mode, new_key, command, opts)
            end,

            --- An advanced wrapper around the map() function, maps several keys if the current neorg mode is the desired one
            ---@param mode string #The neorg mode to bind the keys on
            ---@param keys #table { <neovim_mode> = { { "<key>", "<name-of-keybind>", custom_opts } } } - a table of keybinds
            ---@param opts #table) - the same parameters that should be passed into vim.keymap.set('s opts parameter
            map_to_mode = function(mode, keys, opts)
                -- If the keys table is empty then don't bother doing any parsing
                if vim.tbl_isempty(keys) then
                    return
                end

                -- If the current mode matches the desired mode then
                if mode == "all" or (for_mode or module.required["core.mode"].get_mode()) == mode then
                    -- Loop through all the keybinds for a certain mode
                    for neovim_mode, keymaps in pairs(keys) do
                        -- Loop though all the keymaps in that mode
                        for _, keymap in ipairs(keymaps) do
                            -- Map the keybind and keep track of it using the map() function
                            payload.map(mode, neovim_mode, keymap[1], keymap[2], keymap[3] or opts)
                        end
                    end
                end
            end,

            --- An advanced wrapper around the map() function, maps several keys if the current neorg mode is the desired one
            ---@param mode string #The neorg mode to bind the keys on
            ---@param keys #table { <neovim_mode> = { { "<key>", "<name-of-keybind>", custom_opts } } } - a table of keybinds
            ---@param opts #table) - the same parameters that should be passed into vim.keymap.set('s opts parameter
            map_event_to_mode = function(mode, keys, opts)
                -- If the keys table is empty then don't bother doing any parsing
                if vim.tbl_isempty(keys) then
                    return
                end

                -- If the current mode matches the desired mode then
                if mode == "all" or (for_mode or module.required["core.mode"].get_mode()) == mode then
                    -- Loop through all the keybinds for a certain mode
                    for neovim_mode, keymaps in pairs(keys) do
                        -- Loop though all the keymaps in that mode
                        for _, keymap in ipairs(keymaps) do
                            -- Map the keybind and keep track of it using the map() function
                            payload.map(
                                mode,
                                neovim_mode,
                                keymap[1],
                                "<cmd>Neorg keybind "
                                    .. mode
                                    .. " "
                                    .. table.concat(vim.list_slice(keymap, 2), " ")
                                    .. "<CR>",
                                opts
                            )
                        end
                    end
                end
            end,

            -- Include the current Neorg mode and leader in the contents
            mode = current_mode,
            leader = module.config.public.neorg_leader,
        }

        local function generate_default_functions(cb, ...)
            local funcs = { ... }

            for _, func in ipairs(funcs) do
                local name, to_exec = cb(func, payload[func])

                payload[name] = to_exec
            end
        end

        generate_default_functions(function(name, func)
            return name .. "d", function(...)
                func("norg", ...)
            end
        end, "map", "map_event", "unmap", "remap", "remap_key", "remap_event")

        if
            module.config.public.default_keybinds
            and module.config.public.keybind_presets[module.config.public.keybind_preset]
        then
            module.config.public.keybind_presets[module.config.public.keybind_preset](payload)
        end

        for _, callback in pairs(module.private.requested_keys) do
            callback(payload)
        end

        -- Broadcast our event with the desired payload!
        neorg.events.broadcast_event(
            neorg.events.create(module, "core.keybinds.events.enable_keybinds", payload),
            function()
                for neorg_mode, neovim_modes in pairs(bound_keys) do
                    if neorg_mode == "all" or neorg_mode == current_mode then
                        for mode, keys in pairs(neovim_modes) do
                            for key, data in pairs(keys) do
                                local ok, error = pcall(function()
                                    if action then
                                        action(buf, mode, key, data.command, data.opts or {})
                                    else
                                        local opts = data.opts or {}
                                        opts.buffer = buf

                                        vim.keymap.set(mode, key, data.command, opts)
                                    end
                                end)

                                if not ok then
                                    log.trace(
                                        string.format(
                                            "An error occurred when trying to bind key '%s' in mode '%s' in neorg mode '%s' - %s",
                                            key,
                                            mode,
                                            current_mode,
                                            error
                                        )
                                    )
                                end
                            end
                        end
                    end
                end
            end
        )
    end,

    --- Updates the list of known modes and keybinds for easy autocompletion. Invoked automatically during neorg_post_load().
    sync = function()
        -- Update the first parameter with the new list of modes
        -- NOTE(vhyrro): Is there a way to prevent copying? Can you "unbind" a reference to a table?
        module.public.neorg_commands.keybind.complete[1] = vim.deepcopy(module.required["core.mode"].get_modes())
        table.insert(module.public.neorg_commands.keybind.complete[1], "all")

        -- Update core.neorgcmd's internal tables
        module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
    end,

    request_keys = function(module_name, callback)
        module.private.requested_keys[module_name] = callback
    end,
}

module.private = {
    requested_keys = {},
}

module.neorg_post_load = module.public.sync

module.on_event = function(event)
    neorg.lib.match(event.type)({
        ["core.neorgcmd.events.core.keybinds.trigger"] = function()
            -- Query the current mode and the expected mode (the one passed in by the user)
            local expected_mode = event.content[1]
            local current_mode = module.required["core.mode"].get_mode()

            -- If the modes don't match then don't execute the keybind
            if expected_mode ~= current_mode and expected_mode ~= "all" then
                return
            end

            -- Get the event path to the keybind
            local keybind_event_path = event.content[2]

            -- If it is defined then broadcast the event
            if module.events.defined[keybind_event_path] then
                neorg.events.broadcast_event(
                    neorg.events.create(
                        module,
                        "core.keybinds.events." .. keybind_event_path,
                        vim.list_slice(event.content, 3)
                    )
                )
            else -- Otherwise throw an error
                log.error("Unable to trigger keybind", keybind_event_path, "- the keybind does not exist")
            end
        end,
        ["core.mode.events.mode_created"] = neorg.lib.wrap(module.public.sync),
        ["core.mode.events.mode_set"] = function()
            -- If a new mode has been set then reset all of our keybinds
            module.public.bind_all(event.buffer, function(buf, mode, key)
                vim.api.nvim_buf_del_keymap(buf, mode, key)
            end, event.content.current)
            module.public.bind_all(event.buffer)
        end,
        ["core.autocommands.events.bufenter"] = function()
            if not event.content.norg then
                return
            end

            -- If a new mode has been set then reset all of our keybinds
            module.public.bind_all(event.buffer, function(buf, mode, key)
                vim.api.nvim_buf_del_keymap(buf, mode, key)
            end, module.required["core.mode"].get_previous_mode())
            module.public.bind_all(event.buffer)
        end,
    })
end

module.events.defined = {
    enable_keybinds = neorg.events.define(module, "enable_keybinds"),
}

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.keybinds.trigger"] = true,
    },

    ["core.autocommands"] = {
        bufenter = true,
        bufleave = true,
    },

    ["core.mode"] = {
        mode_created = true,
        mode_set = true,
    },
}

module.examples = {
    ["Create keybinds in your module"] = function()
        -- The process of defining a keybind is only a tiny bit more involved than defining e.g. an autocommand. Let's see what differs in creating a keybind rather than creating an autocommand:

        require("neorg.modules.base")

        local test = neorg.modules.create("test.module")

        test.setup = function()
            return { success = true, requires = { "core.keybinds" } } -- Require the keybinds module
        end

        test.load = function()
            module.required["core.keybinds"].register_keybind(test.name, "my_keybind")

            -- It is also possible to mass initialize keybindings via the public register_keybinds function. It can be used like so:
            -- This should stop redundant calls to the same function or loops within module code.
            module.required["core.keybinds"].register_keybinds(test.name, { "second_keybind", "my_other_keybind" })
        end

        test.on_event = function(event)
            -- The event.split_type field is the type field except split into two.
            -- The split point is .events., meaning if the event type is e.g. "core.keybinds.events.test.module.my_keybind" the value of split_type will be { "core.keybinds", "test.module.my_keybind" }.
            if event.split_type[2] == "test.module.my_keybind" then
                require("neorg.external.log").info("Keybind my_keybind has been pressed!")
            end
        end

        test.events.subscribed = {

            ["core.keybinds"] = {
                -- The event path is a bit different here than it is normally.
                -- Whenever you receive an event, you're used to the path looking like this: <module_path>.events.<event_name>.
                -- Here, however, the path looks like this: <module_path>.events.test.module.<event_name>.
                -- Why is that? Well, the module operates a bit differently under the hood.
                -- In order to create a unique name for every keybind we use the module's name as well.
                -- Meaning if your module is called test.module you will receive an event of type <module_path>.events.test.module.<event_name>.
                ["test.module.my_keybind"] = true, -- Subscribe to the event
            },
        }
    end,

    ["Attach some keys to the create keybind"] = function()
        -- To invoke a keybind, we can then use :Neorg keybind norg test.module.my_keybind.
        -- :Neorg keybind tells core.neorgcmd to invoke a keybind, and the next argument (norg) is the mode that the keybind should be executed in.
        -- Modes are a way to isolate different parts of the neorg environment easily, this includes keybinds too.
        -- core.mode, the module designed to manage modes, is explaned in this own page (see the wiki sidebar).
        -- Just know that by default neorg launches into the norg mode, so you'd most likely want to bind to that.
        -- After the mode you can find the path to the keybind we want to trigger. Soo let's bind it! You should have already read the user keybinds document that details where and how to bind keys, the below code snippet is an extension of that:

        -- (Somewhere in your config)
        -- Require the user callbacks module, which allows us to tap into the core of Neorg
        local neorg_callbacks = require("neorg.callbacks")

        -- Listen for the enable_keybinds event, which signals a "ready" state meaning we can bind keys.
        -- This hook will be called several times, e.g. whenever the Neorg Mode changes or an event that
        -- needs to reevaluate all the bound keys is invoked
        neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybinds)
            -- All your other keybinds

            -- Map all the below keybinds only when the "norg" mode is active
            keybinds.map_event_to_mode("norg", {
                n = {
                    { "<Leader>o", "test.module.my_keybind" },
                },
            }, { silent = true, noremap = true })
        end)

        -- To change the current mode as a user of neorg you can run :Neorg set-mode <mode>.
        -- If you try changing the current mode into a non-existent mode (like :Neorg set-mode a-nonexistent-mode) you will see that all the keybinds you bound to the norg mode won't work anymore!
        -- They'll start working again if you reset the mode back via :Neorg set-mode norg.
    end,
}

return module
