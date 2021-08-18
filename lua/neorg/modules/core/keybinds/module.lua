--[[
	Module for managing keybindings with neorg mode support.

Usage:
	Register keys with core.keybinds's public register_keybind(module_name, name) and register_keybinds(module_name, name) functions.

	Received events come with the type of `core.keybinds.events.<module_name>.<name>`.
	To invoke a keybind, execute `:Neorg keybind <mode> <keybind_path>`, where <mode> is the mode that the keybind will only execute in and
	<keybind_path> is a path like "core.norg.qol.todo_items.todo.task_done".

	Keybindings must be explicitly bound by the user themselves, see https://github.com/vhyrro/neorg/wiki/Keybinds and
	https://github.com/vhyrro/neorg/wiki/User-Keybinds for more info.
--]]

require("neorg.modules.base")
require("neorg.modules")

local module = neorg.modules.create("core.keybinds")

local log = require("neorg.external.log")

module.setup = function()
    return { success = true, requires = { "core.neorgcmd", "core.mode", "core.autocommands" } }
end

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("BufLeave")

    if module.config.public.default_keybinds then
        require("neorg.external.helpers").require(module, "default_keybinds")(module.config.public.neorg_leader)
    end
end

module.private = {
    bound_keys = {},
}

module.config.public = {
    default_keybinds = false,
    neorg_leader = "<Leader>o",
}

module.public = {

    -- Define neorgcmd autocompletions and commands
    neorg_commands = {
        definitions = {
            keybind = {},
        },
        data = {
            keybind = {
                args = 2,
                name = "core.keybinds.trigger",
            },
        },
    },

    version = "0.2",

    keybinds = {},

    -- @Summary Registers a new keybind
    -- @Description Adds a new keybind to the database of known keybinds
    -- @Param  module_name (string) - the name of the module that owns the keybind. Make sure it's an absolute path.
    -- @Param  name (string) - the name of the keybind. The module_name will be prepended to this string to form a unique name.
    register_keybind = function(module_name, name)
        -- Create the full keybind name
        local keybind_name = module_name .. "." .. name

        -- If that keybind is not defined yet then define it
        if not module.events.defined[keybind_name] then
            module.events.defined[keybind_name] = neorg.events.define(module, keybind_name)

            -- Define autocompletion for core.neorgcmd
            module.public.keybinds[keybind_name] = {}
        end

        -- Update core.neorgcmd's internal tables
        module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
    end,

    -- @Summary Registers a batch of keybinds
    -- @Description Like register_keybind(), except registers a batch of them
    -- @Param  module_name (string) - the name of the module that owns the keybind. Make sure it's an absolute path.
    -- @Param  names (list of strings) - a list of strings detailing names of the keybinds. The module_name will be prepended to each one to form a unique name.
    register_keybinds = function(module_name, names)
        -- Loop through each name from the names argument
        for _, name in ipairs(names) do
            -- Create the full keybind name
            local keybind_name = module_name .. "." .. name

            -- If that keybind is not defined yet then define it
            if not module.events.defined[keybind_name] then
                module.events.defined[keybind_name] = neorg.events.define(module, keybind_name)

                -- Define autocompletion for core.neorgcmd
                module.public.keybinds[keybind_name] = {}
            end
        end

        -- Update core.neorgcmd's internal tables
        module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
    end,

    -- @Summary Rebinds all the keys defined via User Callbacks
    bind_all = function()
        -- Make sure to schedule this code block to prevent race conditions
        vim.schedule(function()
            -- If the table is already populated then don't populate it further
            if not vim.tbl_isempty(module.private.bound_keys) then
                return
            end

            -- Broadcast the enable_keybinds event to any user that might have registered a User Callback for it
            local payload

            payload = {

                -- @Summary Maps a Neovim keybind.
                -- @Description Allows Neorg to manage and track mapped keys.
                -- @Param  mode (string) - same as the mode parameter for :h nvim_buf_set_keymap
                -- @Param  key (string) - same as the lhs parameter for :h nvim_buf_set_keymap
                -- @Param  command (string) - same as the rhs parameter for :h nvim_buf_set_keymap
                -- @Param  opts (table) - same as the opts parameter for :h nvim_buf_set_keymap
                map = function(mode, key, command, opts)
                    -- Set the key for the current buffer
                    vim.api.nvim_set_keymap(mode, key, command, opts or {})

                    -- Insert it into the list of tracked keys
                    table.insert(module.private.bound_keys, { mode, key })
                end,

                -- @Summary Maps a bunch of keys for a certain mode
                -- @Description An advanced wrapper around the map() function, maps several keys if the current neorg mode is the desired one
                -- @Param  mode (string) - the neorg mode to bind the keys on
                -- @Param  keys (table { <neovim_mode> = { { "<key>", "<name-of-keybind>" } } }) - a table of keybinds
                -- @Param  opts (table) - the same parameters that should be passed into vim.api.nvim_set_keymap()'s opts parameter
                map_to_mode = function(mode, keys, opts)
                    -- If the keys table is empty then don't bother doing any parsing
                    if vim.tbl_isempty(keys) then
                        return
                    end

                    -- If the current mode matches the desired mode then
                    if mode == "all" or module.required["core.mode"].get_mode() == mode then
                        -- Loop through all the keybinds for a certain mode
                        for neovim_mode, keymaps in pairs(keys) do
                            -- Loop though all the keymaps in that mode
                            for _, keymap in ipairs(keymaps) do
                                -- Map the keybind and keep track of it using the map() function
                                payload.map(neovim_mode, keymap[1], keymap[2], opts)
                            end
                        end
                    end
                end,

                -- @Summary Maps a bunch of keys for a certain mode
                -- @Description An advanced wrapper around the map() function, maps several keys if the current neorg mode is the desired one
                -- @Param  mode (string) - the neorg mode to bind the keys on
                -- @Param  keys (table { <neovim_mode> = { { "<key>", "<name-of-keybind>" } } }) - a table of keybinds
                -- @Param  opts (table) - the same parameters that should be passed into vim.api.nvim_set_keymap()'s opts parameter
                map_event_to_mode = function(mode, keys, opts)
                    -- If the keys table is empty then don't bother doing any parsing
                    if vim.tbl_isempty(keys) then
                        return
                    end

                    -- If the current mode matches the desired mode then
                    if mode == "all" or module.required["core.mode"].get_mode() == mode then
                        -- Loop through all the keybinds for a certain mode
                        for neovim_mode, keymaps in pairs(keys) do
                            -- Loop though all the keymaps in that mode
                            for _, keymap in ipairs(keymaps) do
                                -- Map the keybind and keep track of it using the map() function
                                payload.map(
                                    neovim_mode,
                                    keymap[1],
                                    "<cmd>Neorg keybind " .. mode .. " " .. keymap[2] .. "<CR>",
                                    opts
                                )
                            end
                        end
                    end
                end,

                -- Include the current Neorg mode in the contents
                mode = module.required["core.mode"].get_mode(),
            }

            -- Broadcast our event with the desired payload!
            neorg.events.broadcast_event(neorg.events.create(module, "core.keybinds.events.enable_keybinds", payload))
        end)
    end,

    -- @Summary Unbind all currently defined keys
    -- @Description If the user has used the map() function, as they should have, Neorg will have tracked all the currently bound keymaps.
    --				Thanks to this function all those keys will be cleared as a result of e.g. a mode change.
    unbind_all = function()
        vim.schedule(function()
            -- Loop through every currently defined keybind and unbind it
            for _, mode_key_pair in ipairs(module.private.bound_keys) do
                local ok, error = pcall(vim.api.nvim_del_keymap, mode_key_pair[1], mode_key_pair[2])

                if not ok then
                    log.info("Failed to unset a certain key with error:", error)
                end
            end
            -- Reset the bound keys table
            module.private.bound_keys = {}
        end)
    end,

    -- @Summary Synchronizes all autocompletions
    -- @Description Updates the list of known modes and keybinds for easy autocompletion. Invoked automatically during neorg_post_load().
    sync = function()
        -- Reset all the autocompletions
        module.public.neorg_commands.definitions.keybind = {}

        -- Grab all the modes
        local modes = module.required["core.mode"].get_modes()

        -- Set autocompletion for the "all" mode
        module.public.neorg_commands.definitions.keybind.all = module.public.keybinds

        -- Convert the list of modes into completion entries for core.neorgcmd
        for _, mode in ipairs(modes) do
            module.public.neorg_commands.definitions.keybind[mode] = module.public.keybinds
        end

        -- Update core.neorgcmd's internal tables
        module.required["core.neorgcmd"].add_commands_from_table(module.public.neorg_commands)
    end,
}

module.neorg_post_load = module.public.sync

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.core.keybinds.trigger" then
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
            neorg.events.broadcast_event(neorg.events.create(module, "core.keybinds.events." .. keybind_event_path))
        else -- Otherwise throw an error
            log.error("Unable to trigger keybind", keybind_event_path, "- the keybind does not exist")
        end
    elseif event.type == "core.mode.events.mode_created" then
        -- If a new mode has been created then resync
        module.public.sync()
    elseif event.type == "core.mode.events.mode_set" then
        -- If a new mode has been set then reset all of our keybinds
        module.public.unbind_all()
        module.public.bind_all()
    elseif event.type == "core.autocommands.events.bufenter" then
        -- If we have entered a buffer then rebind all keys
        module.public.bind_all()
    elseif event.type == "core.autocommands.events.bufleave" then
        -- If we have left a buffer then unbind all keys
        module.public.unbind_all()
    end
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

return module
