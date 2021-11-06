# Using `core.dirman`'s API

### Functions
This segment will detail all of the functions `core.dirman` exposes. All of these functions reside in the `public` table.

- `get_workspaces()` - returns a list of all the workspaces.
- `get_workspaces_names()` - returns an array of all the workspace names (without their paths)
- ```lua
  -- @Summary Retrieve a workspace
  -- @Description If present retrieve a workspace's path by its name, else returns nil
  -- @Param  name (string) - the name of the workspace
  get_workspace = function(name)
  ```
- ```lua
  -- @Summary Retrieves the current workspace
  -- @Description Returns a table in the format { "workspace_name", "path" }
  get_current_workspace = function()
  ```
- ```lua
  -- @Summary Sets the current workspace
  -- @Description Sets the workspace to the one specified (if it exists) and broadcasts the workspace_changed event
  --              Returns true if the workspace is set correctly, else returns false
  -- @Param  ws_name (name) - the name of a valid namespace we want to switch to
  set_workspace = function(ws_name)
  ```
- ```lua
  -- @Summary Adds a new workspace
  -- @Description Dynamically defines a new workspace if the name isn't already occupied and broadcasts the workspace_added event
  --              Returns true if the workspace is added successfully, else returns false
  -- @Param  workspace_name (string) - the unique name of the new workspace
  -- @Param  workspace_path (string) - a full path to the workspace root
  add_workspace = function(workspace_name, workspace_path)
  ```
- ```lua
  -- @Summary Returns the closes match from the cwd to a valid workspace
  -- @Description If the file we opened is within a workspace directory, returns the name of the workspace, else returns nil
  get_workspace_match = function()
  ```
- ```lua
  -- @Summary Updates the current working directory to the workspace root
  -- @Description Uses the get_workspace_match() function to determine the root of the workspace, then changes into that directory
  update_cwd = function()
  ```
- ```lua
  -- @Summary Synchronizes the module to the Neorg environment
  -- @Description Updates completions for the :Neorg command
  sync = function()
  ```

### Events
`core.dirman` exposes two events you can hook into - `workspace_changed` and `workspace_added`.
- `workspace_changed` - invoked whenever a workspace is changed, its content is a table with the format `{ old = <old_workspace>, new = <new_workspace }`,
  where `new` is the new workspace we are about to switch to and `old` is the previous one we were in is the previous one we were in.
- `workspace_added` - triggered whenever a new workspace gets added during runtime, its content is a table with the format `{ workspace_name, workspace_path }`,
  where `workspace_name` is the name of the new workspace that was just created and `workspace_path` is the location that workspace points to.
