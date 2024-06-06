--[[
    file: Dirman
    title: The Most Critical Component of any Organized Workflow
    description: The `dirman` module handles different collections of notes in separate directories.
    summary: This module is be responsible for managing directories full of .norg files.
    ---
`core.dirman` provides other modules the ability to see which directories the user is in, where
each note collection is stored and how to interact with it.

When writing notes, it is often crucial to have notes on a certain topic be isolated from notes on another topic.
Dirman achieves this with a concept of "workspaces", which are named directories full of `.norg` notes.

To use `core.dirman`, simply load up the module in your configuration and specify the directories you would like to be managed for you:

```lua
require('neorg').setup {
    load = {
        ["core.defaults"] = {},
        ["core.dirman"] = {
            config = {
                workspaces = {
                    my_ws = "~/neorg", -- Format: <name_of_workspace> = <path_to_workspace_root>
                    my_other_notes = "~/work/notes",
                },
                index = "index.norg", -- The name of the main (root) .norg file
            }
        }
    }
}
```

To query the current workspace, run `:Neorg workspace`. To set the workspace, run `:Neorg workspace <workspace_name>`.

### Changing the Current Working Directory
After a recent update `core.dirman` will no longer change the current working directory after switching
workspace. To get the best experience it's recommended to set the `autochdir` Neovim option.


### Create a new note
You can use dirman to create new notes in your workspaces.

```lua
local dirman = require('neorg').modules.get_module("core.dirman")
dirman.create_file("my_file", "my_ws", {
    no_open  = false,  -- open file after creation?
    force    = false,  -- overwrite file if exists
    metadata = {}      -- key-value table for metadata fields
})
```
--]]

local Path = require("pathlib")

local neorg = require("neorg.core")
local log, modules, utils = neorg.log, neorg.modules, neorg.utils
local dirman_utils

local module = modules.create("core.dirman")

module.setup = function()
    return {
        success = true,
        requires = { "core.autocommands", "core.ui", "core.storage", "core.dirman.utils" },
    }
end

module.load = function()
    -- Go through every workspace and expand special symbols like ~
    for name, workspace_location in pairs(module.config.public.workspaces) do
        -- module.config.public.workspaces[name] = vim.fn.expand(vim.fn.fnameescape(workspace_location)) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        module.config.public.workspaces[name] = Path(workspace_location):resolve():to_absolute()
    end

    dirman_utils = module.required["core.dirman.utils"]

    modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybind(module.name, "new.note")
    end)

    -- Used to detect when we've entered a buffer with a potentially different cwd
    module.required["core.autocommands"].enable_autocommand("BufEnter", true)

    modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            index = {
                args = 0,
                name = "dirman.index",
            },
        })
    end)

    -- Synchronize core.neorgcmd autocompletions
    module.public.sync()

    if module.config.public.open_last_workspace and vim.fn.argc(-1) == 0 then
        if module.config.public.open_last_workspace == "default" then
            if not module.config.public.default_workspace then
                log.warn(
                    'Configuration error in `core.dirman`: the `open_last_workspace` option is set to "default", but no default workspace is provided in the `default_workspace` configuration variable. Defaulting to opening the last known workspace.'
                )
                module.public.set_last_workspace()
                return
            end

            module.public.open_workspace(module.config.public.default_workspace)
        else
            module.public.set_last_workspace()
        end
    elseif module.config.public.default_workspace then
        module.public.set_workspace(module.config.public.default_workspace)
    end
end

module.config.public = {
    -- The list of active Neorg workspaces.
    --
    -- There is always an inbuilt workspace called `default`, whose location is
    -- set to the Neovim current working directory on boot.
    ---@type table<string, PathlibPath>
    workspaces = {
        default = require("pathlib").cwd(),
    },
    -- The name for the index file.
    --
    -- The index file is the "entry point" for all of your notes.
    index = "index.norg",
    -- The default workspace to set whenever Neovim starts.
    default_workspace = nil,
    -- Whether to open the last workspace's index file when `nvim` is executed
    -- without arguments.
    --
    -- May also be set to the string `"default"`, due to which Neorg will always
    -- open up the index file for the workspace defined in `default_workspace`.
    open_last_workspace = false,
    -- Whether to use core.ui.text_popup for `dirman.new.note` event.
    -- if `false`, will use vim's default `vim.ui.input` instead.
    use_popup = true,
}

module.private = {
    ---@type { [1]: string, [2]: PathlibPath }
    current_workspace = { "default", Path.cwd() },
}

---@class core.dirman
module.public = {
    get_workspaces = function()
        return module.config.public.workspaces
    end,
    ---@return string[]
    get_workspace_names = function()
        return vim.tbl_keys(module.config.public.workspaces)
    end,
    --- If present retrieve a workspace's path by its name, else returns nil
    ---@param name string #The name of the workspace
    get_workspace = function(name)
        return module.config.public.workspaces[name]
    end,
    --- Returns a table in the format { "workspace_name", "path" }
    get_current_workspace = function()
        return module.private.current_workspace
    end,
    --- Sets the workspace to the one specified (if it exists) and broadcasts the workspace_changed event
    ---@return boolean True if the workspace is set correctly, false otherwise
    ---@param ws_name string #The name of a valid namespace we want to switch to
    set_workspace = function(ws_name)
        -- Grab the workspace location
        local workspace = module.config.public.workspaces[ws_name]
        -- Create a new object describing our new workspace
        local new_workspace = { ws_name, workspace }

        -- If the workspace does not exist then error out
        if not workspace then
            log.warn("Unable to set workspace to", workspace, "- that workspace does not exist")
            return false
        end

        -- Create the workspace directory if not already present
        workspace:mkdir(Path.const.o755, true)

        -- Cache the current workspace
        local current_ws = vim.deepcopy(module.private.current_workspace)

        -- Set the current workspace to the new workspace object we constructed
        module.private.current_workspace = new_workspace

        if ws_name ~= "default" then
            module.required["core.storage"].store("last_workspace", ws_name)
        end

        -- Broadcast the workspace_changed event with all the necessary information
        modules.broadcast_event(
            assert(
                modules.create_event(
                    module,
                    "core.dirman.events.workspace_changed",
                    { old = current_ws, new = new_workspace }
                )
            )
        )

        return true
    end,
    --- Dynamically defines a new workspace if the name isn't already occupied and broadcasts the workspace_added event
    ---@return boolean True if the workspace is added successfully, false otherwise
    ---@param workspace_name string #The unique name of the new workspace
    ---@param workspace_path string|PathlibPath #A full path to the workspace root
    add_workspace = function(workspace_name, workspace_path)
        -- If the module already exists then bail
        if module.config.public.workspaces[workspace_name] then
            return false
        end

        workspace_path = Path(workspace_path):resolve():to_absolute()
        -- Set the new workspace and its path accordingly
        module.config.public.workspaces[workspace_name] = workspace_path
        -- Broadcast the workspace_added event with the newly added workspace as the content
        modules.broadcast_event(
            assert(
                modules.create_event(module, "core.dirman.events.workspace_added", { workspace_name, workspace_path })
            )
        )

        -- Sync autocompletions so the user can see the new workspace
        module.public.sync()

        return true
    end,
    --- If the file we opened is within a workspace directory, returns the name of the workspace, else returns nil
    get_workspace_match = function()
        -- Cache the current working directory
        module.config.public.workspaces.default = Path.cwd()

        local file = Path(vim.fn.expand("%:p"))

        -- Name of matching workspace. Falls back to "default"
        local ws_name = "default"

        -- Store the depth of the longest match
        local longest_match = 0

        -- Find a matching workspace
        for workspace, location in pairs(module.config.public.workspaces) do
            if workspace ~= "default" then
                if file:is_relative_to(location) and location:depth() > longest_match then
                    ws_name = workspace
                    longest_match = location:depth()
                end
            end
        end

        return ws_name
    end,
    --- Uses the `get_workspace_match()` function to determine the root of the workspace based on the
    --- current working directory, then changes into that workspace
    set_closest_workspace_match = function()
        -- Get the closest workspace match
        local ws_match = module.public.get_workspace_match()

        -- If that match exists then set the workspace to it!
        if ws_match then
            module.public.set_workspace(ws_match)
        else
            -- Otherwise try to reset the workspace to the default
            module.public.set_workspace("default")
        end
    end,
    --- Updates completions for the :Neorg command
    sync = function()
        -- Get all the workspace names
        local workspace_names = module.public.get_workspace_names()

        -- Add the command to core.neorgcmd so it can be used by the user!
        modules.await("core.neorgcmd", function(neorgcmd)
            neorgcmd.add_commands_from_table({
                workspace = {
                    max_args = 1,
                    name = "dirman.workspace",
                    complete = { workspace_names },
                },
            })
        end)
    end,

    ---@class core.dirman.create_file_opts
    ---@field no_open? boolean do not open the file after creation?
    ---@field force? boolean overwrite file if it already exists?
    ---@field metadata? core.esupports.metagen.metadata metadata fields, if provided inserts metadata - an empty table uses default values

    --- Takes in a path (can include directories) and creates a .norg file from that path
    ---@param path string|PathlibPath a path to place the .norg file in
    ---@param workspace? string workspace name
    ---@param opts? core.dirman.create_file_opts additional options
    create_file = function(path, workspace, opts)
        opts = opts or {}

        -- Grab the current workspace's full path
        local fullpath

        if workspace ~= nil then
            fullpath = module.public.get_workspace(workspace)
        else
            fullpath = module.public.get_current_workspace()[2]
        end

        if fullpath == nil then
            log.error("Error in fetching workspace path")
            return
        end

        local destination = (fullpath / path):add_suffix(".norg")

        -- Generate parents just in case
        destination:parent_assert():mkdir(Path.const.o755 + 4 * math.pow(8, 4), true) -- 40755(oct)

        -- Create or overwrite the file
        local fd = destination:fs_open(opts.force and "w" or "a", Path.const.o644, false)
        if fd then
            vim.loop.fs_close(fd)
        end

        -- Broadcast file creation event
        local bufnr = module.public.get_file_bufnr(destination:tostring())
        modules.broadcast_event(
            assert(modules.create_event(module, "core.dirman.events.file_created", { buffer = bufnr, opts = opts }))
        )

        if not opts.no_open then
            -- Begin editing that newly created file
            vim.cmd("e " .. destination:cmd_string() .. "| w")
        end
    end,

    --- Takes in a workspace name and a path for a file and opens it
    ---@param workspace_name string #The name of the workspace to use
    ---@param path string|PathlibPath #A path to open the file (e.g directory/filename.norg)
    open_file = function(workspace_name, path)
        local workspace = module.public.get_workspace(workspace_name)

        if workspace == nil then
            return
        end

        vim.cmd("e " .. (workspace / path):cmd_string() .. " | w")
    end,
    --- Reads the neorg_last_workspace.txt file and loads the cached workspace from there
    set_last_workspace = function()
        -- Attempt to open the last workspace cache file in read-only mode
        local storage = modules.get_module("core.storage")

        if not storage then
            log.trace("Module `core.storage` not loaded, refusing to load last user's workspace.")
            return
        end

        local last_workspace = storage.retrieve("last_workspace")
        last_workspace = type(last_workspace) == "string" and last_workspace
            or module.config.public.default_workspace
            or ""

        local workspace_path = module.public.get_workspace(last_workspace)

        if not workspace_path then
            log.trace("Unable to switch to workspace '" .. last_workspace .. "'. The workspace does not exist.")
            return
        end

        -- If we were successful in switching to that workspace then begin editing that workspace's index file
        if module.public.set_workspace(last_workspace) then
            vim.cmd("e " .. (workspace_path / module.public.get_index()):cmd_string())

            utils.notify("Last Workspace -> " .. workspace_path)
        end
    end,
    --- Checks for file existence by supplying a full path in `filepath`
    ---@param filepath string|PathlibPath
    file_exists = function(filepath)
        return Path(filepath):exists()
    end,
    --- Get the bufnr for a `filepath` (full path)
    ---@param filepath string|PathlibPath
    get_file_bufnr = function(filepath)
        if module.public.file_exists(filepath) then
            local uri = vim.uri_from_fname(tostring(filepath))
            return vim.uri_to_bufnr(uri)
        end
    end,
    --- Returns a list of all files relative path from a `workspace_name`
    ---@param workspace_name string
    ---@return PathlibPath[]|nil
    get_norg_files = function(workspace_name)
        local res = {}
        local workspace = module.public.get_workspace(workspace_name)

        if not workspace then
            return
        end

        for path in workspace:fs_iterdir(true, 20) do
            if path:is_file(true) and path:suffix() == ".norg" then
                table.insert(res, path)
            end
        end

        return res
    end,
    --- Sets the current workspace and opens that workspace's index file
    ---@param workspace string #The name of the workspace to open
    open_workspace = function(workspace)
        -- If we have, then query that workspace
        local ws_match = module.public.get_workspace(workspace)

        -- If the workspace does not exist then give the user a nice error and bail
        if not ws_match then
            log.error('Unable to switch to workspace - "' .. workspace .. '" does not exist')
            return
        end

        -- Set the workspace to the one requested
        module.public.set_workspace(workspace)

        -- If we're switching to a workspace that isn't the default workspace then enter the index file
        if workspace ~= "default" then
            vim.cmd("e " .. (ws_match / module.public.get_index()):cmd_string())
        end
    end,
    --- Touches a file in workspace
    ---@param path string|PathlibPath
    ---@param workspace string
    touch_file = function(path, workspace)
        vim.validate({
            path = { path, "string", "table" },
            workspace = { workspace, "string" },
        })

        local ws_match = module.public.get_workspace(workspace)

        if not workspace then
            return false
        end

        return (ws_match / path):touch(Path.const.o644, true)
    end,
    get_index = function()
        return module.config.public.index
    end,
}

module.on_event = function(event)
    -- If somebody has executed the :Neorg workspace command then
    if event.type == "core.neorgcmd.events.dirman.workspace" then
        -- Have we supplied an argument?
        if event.content[1] then
            module.public.open_workspace(event.content[1])

            vim.schedule(function()
                local new_workspace = module.public.get_workspace(event.content[1])

                if not new_workspace then
                    return
                end

                utils.notify("New Workspace: " .. event.content[1] .. " -> " .. new_workspace)
            end)
        else -- No argument supplied, simply print the current workspace
            -- Query the current workspace
            local current_ws = module.public.get_current_workspace()
            -- Nicely print it. We schedule_wrap here because people with a configured logger will have this message
            -- silenced by other trace logs
            vim.schedule(function()
                utils.notify("Current Workspace: " .. current_ws[1] .. " -> " .. current_ws[2])
            end)
        end
    end

    -- If somebody has executed the :Neorg index command then
    if event.type == "core.neorgcmd.events.dirman.index" then
        local current_ws = module.public.get_current_workspace()

        local index_path = current_ws[2] / module.public.get_index()

        if vim.fn.filereadable(index_path:tostring("/")) == 0 then
            if current_ws[1] == "default" then
                utils.notify(table.concat({
                    "Index file cannot be created in 'default' workspace to avoid confusion.",
                    "If this is intentional, manually create an index file beforehand to use this command.",
                }, " "))
                return
            end
            if not index_path:touch(Path.const.o644, true) then
                utils.notify(
                    table.concat({
                        "Unable to create '",
                        module.public.get_index(),
                        "' in the current workspace - are your filesystem permissions set correctly?",
                    }),
                    vim.log.levels.WARN
                )
                return
            end
        end

        dirman_utils.edit_file(index_path:cmd_string())
        return
    end

    -- If the user has executed a keybind to create a new note then create a prompt
    if event.type == "core.keybinds.events.core.dirman.new.note" then
        if module.config.public.use_popup then
            module.required["core.ui"].create_prompt("NeorgNewNote", "New Note: ", function(text)
                -- Create the file that the user has entered
                module.public.create_file(text)
            end, {
                center_x = true,
                center_y = true,
            }, {
                width = 25,
                height = 1,
                row = 10,
                col = 0,
            })
        else
            vim.ui.input({ prompt = "New Note: " }, function(text)
                if text ~= nil and #text > 0 then
                    module.public.create_file(text)
                end
            end)
        end
    end
end

module.events.defined = {
    workspace_changed = modules.define_event(module, "workspace_changed"),
    workspace_added = modules.define_event(module, "workspace_added"),
    workspace_cache_empty = modules.define_event(module, "workspace_cache_empty"),
    file_created = modules.define_event(module, "file_created"),
}

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
    },
    ["core.dirman"] = {
        workspace_changed = true,
    },
    ["core.neorgcmd"] = {
        ["dirman.workspace"] = true,
        ["dirman.index"] = true,
    },
    ["core.keybinds"] = {
        ["core.dirman.new.note"] = true,
    },
}

return module
