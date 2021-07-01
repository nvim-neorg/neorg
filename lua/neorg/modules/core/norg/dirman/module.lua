--[[
	 Directory manager for Neorg.
	 This module will be responsible for managing directories full of .norg files. It will provide other modules the ability to see which directories the user is in,
	 automatically changing directories, and other API bits and bobs that will allow things like telescope.nvim integration.

USAGE:
	To use core.norg.dirman, simply load up the module in your configuration and specify the directories you want to be managed for you:

	require('neorg').setup {
		load = {
			["core.defaults"] = {},
			["core.norg.dirman"] = {
				config = {
					workspaces = {
						my_ws = "~/neorg", -- Format: <name_of_workspace> = <path_to_workspace_root>
						my_other_notes = "~/work/notes",
					},
					autodetect = true, -- Automatically detect whether you are in a workspace whenever you open a file
					autochdir = true, -- Automatically change the directory to the current workspace's root every time
				}
			}
		}
	}

	To query the current workspace, run `:Neorg workspace`. To set the workspace, run `:Neorg workspace <workspace_name>`.
	Note that this requires core.neorgcmd to be docked into the Neorg environment and loaded.

	To stop limiting yourself to a single namespace, switch to the `default` workspace, like so:
	`:Neorg workspace default`. This will put you in your initial cwd upon launching Neovim and will no longer
	automatically switch directories for you.

REQUIRES:
	`core.autocommands` - used to detect changes to the current working directory via DirChanged
	`core.neorgcmd` (optional, but recommended) - used to provide frontend features for switching workspaces, rather than simply API calls
--]]

require('neorg.modules.base')
require('neorg.modules')

local module = neorg.modules.create("core.norg.dirman")

module.setup = function()
	return { success = true, requires = { "core.autocommands" } }
end

module.load = function()
	-- Enable the DirChanged autocmd to detect changes to the cwd
	module.required["core.autocommands"].enable_autocommand("DirChanged", true)

	-- If the user wants workspace autodetection
	if module.config.public.autodetect then
		module.public.update_cwd()
	end

	module.public.sync()
end

module.config.public = {
	-- The list of active workspaces
	workspaces = {
		default = vim.fn.getcwd()
	},

	-- Automatically detect whenever we have entered a subdirectory of a workspace
	autodetect = true,
	-- Automatically change the directory to the root of the workspace every time
	autochdir = true,
}

module.private = {
	current_workspace = { "default", vim.fn.getcwd() }
}

module.public = {

	-- @Summary Returns a list of all the workspaces
	get_workspaces = function()
		return module.config.public.workspaces
	end,

	-- @Summary Returns an array of all the workspace names (without their paths)
	get_workspace_names = function()
		return vim.tbl_keys(module.config.public.workspaces)
	end,

	-- @Summary Retrieve a workspace
	-- @Description If present retrieve a workspace's path by its name, else returns nil
	-- @Param  name (string) - the name of the workspace
	get_workspace = function(name)
		local workspace = module.config.public.workspaces[name]

		if not workspace then
			log.warn("Unable to grab workspace with name", name, "- such a workspace has not been defined.")
			return nil
		end

		return workspace
	end,

	-- @Summary Retrieves the current workspace
	-- @Description Returns a table in the format { "workspace_name", "path" }
	get_current_workspace = function()
		return module.private.current_workspace
	end,

	-- @Summary Sets the current workspace
	-- @Description Sets the workspace to the one specified (if it exists) and broadcasts the workspace_changed event
	--				Returns true if the workspace is set correctly, else returns false
	-- @Param  ws_name (name) - the name of a valid namespace we want to switch to
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

		-- Cache the current workspace
		local current_ws = vim.deepcopy(module.private.current_workspace)
		-- Set the current workspace to the new workspace object we constructed
		module.private.current_workspace = new_workspace

		-- Broadcast the workspace_changed event with all the necessary information
		neorg.events.broadcast_event(neorg.events.create(module, "core.norg.dirman.events.workspace_changed", { old = current_ws, new = new_workspace }))

		return true
	end,

	-- @Summary Adds a new workspace
	-- @Description Dynamically defines a new workspace if the name isn't already occupied and broadcasts the workspace_added event
	--				Returns true if the workspace is added successfully, else returns false
	-- @Param  workspace_name (string) - the unique name of the new workspace
	-- @Param  workspace_path (string) - a full path to the workspace root
	add_workspace = function(workspace_name, workspace_path)

		-- If the module already exists then bail
		if module.config.public.workspaces[workspace_name] then
			return false
		end

		-- Set the new workspace and its path accordingly
		module.config.public.workspaces[workspace_name] = workspace_path
		-- Broadcast the workspace_added event with the newly added workspace as the content
		neorg.events.broadcast_event(neorg.events.create(module, "core.norg.dirman.events.workspace_added", { workspace_name, workspace_path }))

		return true
	end,

	-- @Summary Returns the closes match from the cwd to a valid workspace
	-- @Description If the file we opened is within a workspace directory, returns the name of the workspace, else returns nil
	get_workspace_match = function()
		-- Grab the working directory of the current open file
		local realcwd = vim.fn.expand("%:p:h")

		-- Store the length of the last match
		local last_length = 0

		-- The final result
		local result = ""

		-- Find a matching workspace
		for workspace, location in pairs(module.config.public.workspaces) do
			-- Expand all special symbols like ~ etc.
			local expanded = vim.fn.expand(vim.fn.expand(location))

			-- If the workspace location is a parent directory of our current realcwd
			-- or if the ws location is the same then set it as the real workspace
			-- We check this last_length here because if a match is longer
			-- than the previous one then we can say it is a much more precise
			-- match and hence should be prioritized
			if realcwd:find(expanded) and #expanded > last_length then
				-- Set the result to the workspace name
				result = workspace
				-- Set the last_length variable to the new length
				last_length = #expanded
			end
		end

		return result:len() ~= 0 and result or nil
	end,

	-- @Summary Updates the current working directory to the workspace root
	-- @Description Uses the get_workspace_match() function to determine the root of the workspace, then changes into that directory
	update_cwd = function()
		-- Get the closest workspace match
		local ws_match = module.public.get_workspace_match()

		-- If that match exists then set the workspace to it!
		if ws_match then
			module.public.set_workspace(ws_match)
		end
	end,

	-- @Summary Synchronizes the module to the Neorg environment
	-- @Description Updates completions for the :Neorg command
	sync = function()
		-- Grab the core.neorgcmd module
		local neorgcmd = neorg.modules.get_module("core.neorgcmd")

		-- If it is not loaded then bail!
		if not neorgcmd then
			return
		end

		-- Get all the workspace names
		local workspace_names = module.public.get_workspace_names()

		-- Construct a table to be used by core.neorgcmd for autocompletion
		local workspace_autocomplete = (function()
			local result = {}

			for _, ws_name in ipairs(workspace_names) do
				result[ws_name] = {}
			end

			return result
		end)()

		-- Add the command to core.neorgcmd so it can be used by the user!
		neorgcmd.add_commands_from_table({
			definitions = {
				workspace = workspace_autocomplete
			},
			data = {
				workspace = {
					max_args = 1,
					name = "dirman.workspace"
				}
			}
		})
	end

}

module.on_event = function(event)

	-- If the workspace has changed then
	if event.type == "core.norg.dirman.events.workspace_changed" then
		-- Grab the current working directory and the current workspace
		local new_cwd = vim.fn.getcwd()
		local current_workspace = module.public.get_current_workspace()

		-- If the current working directory is not the same as the workspace root then set it
		if current_workspace[2] ~= new_cwd then
			vim.cmd("cd! " .. current_workspace[2])
		end
	end

	-- If the user has changed directories and the autochdir flag is set then
	if event.type == "core.autocommands.events.dirchanged" and module.config.public.autochdir then
		-- Grab the current working directory and the current workspace
		local new_cwd = vim.fn.getcwd()
		local current_workspace = module.public.get_current_workspace()

		-- If the current workspace is not the default and if the cwd is not the same as the workspace root then set it
		if current_workspace[1] ~= "default" and current_workspace[2] ~= new_cwd then
			vim.cmd("cd! " .. current_workspace[2])
		end
	end

	-- If somebody has executed the :Neorg workspace command then
	if event.type == "core.neorgcmd.events.dirman.workspace" then
		-- Have we supplied an argument?
		if event.content[1] then
			-- If we have, then query that workspace
			local ws_match = module.public.get_workspace(event.content[1])

			-- If the workspace does not exist then give the user a nice error and bail
			if not ws_match then
				log.error("Unable to switch to workspace - \"" .. event.content[1] .. "\" does not exist")
				return
			end

			-- Set the workspace to the one requested
			module.public.set_workspace(event.content[1])
			vim.schedule(function() vim.notify("New Workspace: " .. event.content[1] .. " -> " .. ws_match) end)
		else -- No argument supplied, simply print the current workspace
			-- Query the current workspace
			local current_ws = module.public.get_current_workspace()
			-- Nicely print it. We schedule_wrap here because people with a configured logger will have this message
			-- silenced by other trace logs
			vim.schedule(function() vim.notify("Current Workspace: " ..  current_ws[1] .. " -> " .. current_ws[2]) end)
		end
	end
end

module.events.defined = {
	workspace_changed = neorg.events.define(module, "workspace_changed"),
	workspace_added = neorg.events.define(module, "workspace_added")
}

module.events.subscribed = {
	["core.autocommands"] = {
		dirchanged = true
	},

	["core.norg.dirman"] = {
		workspace_changed = true
	},

	["core.neorgcmd"] = {
		["dirman.workspace"] = true
	}
}

return module
