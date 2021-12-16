--[[
    File: Keybinds
    Title: The Keybinds Module
	Summary: Module for managing keybindings with Neorg mode support.
    ---
If you're a developer, check out the [examples](#examples).
See https://github.com/vhyrro/neorg/wiki/User-Keybinds for more info.
--]]

require("neorg.modules.base")
require("neorg.modules")

local module = neorg.modules.create("core.keybinds")

local log = require("neorg.external.log")

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
        --If you try changing the current mode into a non-existent mode (like :Neorg set-mode a-nonexistent-mode) you will see that all the keybinds you bound to the norg mode won't work anymore!
        --They'll start working again if you reset the mode back via :Neorg set-mode norg.
    end,
}

module.setup = function()
    return {
        success = true,
        requires = { "core.neorgcmd", "core.mode", "core.autocommands" },
        imports = { "default_keybinds" },
    }
end

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("BufLeave")

    if module.config.public.default_keybinds then
        module.public.generate_keybinds(module.config.public.neorg_leader)
    end
end

module.config.public = {
    -- Use the default keybinds provided in https://github.com/nvim-neorg/neorg/blob/main/lua/neorg/modules/core/keybinds/default_keybinds.lua
    default_keybinds = false,
    -- Prefix for some Neorg keybinds
    neorg_leader = "<Leader>o",
}

---@class core.keybinds
module.public = {

    -- Define neorgcmd autocompletions and commands
    neorg_commands = {
        definitions = {
            keybind = {},
        },
        data = {
            keybind = {
                min_args = 2,
                name = "core.keybinds.trigger",
            },
        },
    },

    version = "0.2",

    keybinds = {},

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
    bind_all = function(action, for_mode)
        local current_mode = for_mode or module.required["core.mode"].get_mode()

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
                local ok, error = pcall(function()
                    if action then
                        action(0, mode, key, command, opts or {})
                    else
                        vim.api.nvim_buf_set_keymap(0, mode, key, command, opts or {})
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
                if mode == "all" or (for_mode or module.required["core.mode"].get_mode()) == mode then
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
                if mode == "all" or (for_mode or module.required["core.mode"].get_mode()) == mode then
                    -- Loop through all the keybinds for a certain mode
                    for neovim_mode, keymaps in pairs(keys) do
                        -- Loop though all the keymaps in that mode
                        for _, keymap in ipairs(keymaps) do
                            -- Map the keybind and keep track of it using the map() function
                            payload.map(
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

            -- Include the current Neorg mode in the contents
            mode = current_mode,
        }

        -- Broadcast our event with the desired payload!
        neorg.events.broadcast_event(neorg.events.create(module, "core.keybinds.events.enable_keybinds", payload))

        -- If we have defined the default_keybinds as a table then that means the user wants to change some keys
        if type(module.config.public.default_keybinds) == "table" then
            -- Go through each mode, since the table should look like:
            -- <mode> = {
            --  <keybind> = {
            --   event = 'core.integrations.treesitter.next.heading',
            --   mode = 'all', -- Only works when the 'event key is provided'
            --   OR
            --   action = '<cmd>lua print("Hello world!")<CR>'
            --  }
            -- }
            for mode, keybinds in pairs(module.config.public.default_keybinds) do
                -- Go through every keybind and extract its data
                for keybind, data in pairs(keybinds) do
                    if keybind ~= "unbind" then
                        if data.event then
                            vim.api.nvim_set_keymap(
                                mode,
                                keybind,
                                "<cmd>Neorg keybind " .. (data.mode or "norg") .. " " .. data.event .. "<CR>",
                                data.opts or {}
                            )
                        elseif data.action then
                            if data.mode then
                                log.warn(
                                    "Warning in keybind definition for",
                                    keybind,
                                    "- 'mode' key has no effect when paired with the 'action' key."
                                )
                            end
                            vim.api.nvim_set_keymap(mode, keybind, data.action, data.opts or {})
                        else
                            log.error(
                                "Error in keybind definition. You need to supply one of these keys: 'event' or 'key'."
                            )
                        end
                    else
                        -- If we're dealing with a table called "unbind" then go through all the strings defined there
                        -- and unbind each key
                        for _, to_unbind in ipairs(data) do
                            pcall(vim.api.nvim_buf_del_keymap, 0, mode, to_unbind)
                        end
                    end
                end
            end
        end
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
    elseif event.type == "core.mode.events.mode_created" then
        -- If a new mode has been created then resync
        module.public.sync()
    elseif event.type == "core.mode.events.mode_set" then
        -- If a new mode has been set then reset all of our keybinds
        module.public.bind_all(function(buf, mode, key)
            vim.api.nvim_buf_del_keymap(buf, mode, key)
        end, event.content.current)
        module.public.bind_all()
    elseif event.type == "core.autocommands.events.bufenter" and event.content.norg then
        -- If a new mode has been set then reset all of our keybinds
        module.public.bind_all(function(buf, mode, key)
            vim.api.nvim_buf_del_keymap(buf, mode, key)
        end, module.required["core.mode"].get_previous_mode())
        module.public.bind_all()
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
