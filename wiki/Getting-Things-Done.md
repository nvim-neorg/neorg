# Base module for GTD workflow

## Summary
Manages your tasks with Neorg using the Getting Things Done methodology.

## Overview
It's here where the keybinds and commands are created in order to interact with GTD stuff

- Call the command `:Neorg gtd views` to nicely show your tasks and projects
- Create a new task with `:Neorg gtd capture`
- Edit the task under the cursor with `:Neorg gtd edit`

## Usage
### How to Apply
- To manually load the module, place this code in your Neorg setup:
  ```lua
  ["core.gtd.base"] = {
     config = { -- Note that this table is optional and doesn't need to be provided
         -- Configuration here
     }
  }
  ```
  Consult the [configuration](#Configuration) section to see how you can configure `core.gtd.base` to your liking.

### Configuration
- `workspace`
```lua
"default"
```
- `default_lists`
```lua
{
  inbox = "inbox.norg"
}
```
- `exclude`
```lua
{}
```
## Developer Usage
### Public API
This segment will detail all of the functions `core.gtd.base` exposes. All of these functions reside in the `public` table.

No public functions exposed.

### Examples
None Provided

## Extra Info
### Version
This module supports at least version **0.0.8**.
The current Neorg version is **0.0.8**.

### Requires
- `core.norg.dirman` - undocumented module
- `core.keybinds` - undocumented module
- [`core.gtd.ui`](https://github.com/nvim-neorg/neorg/wiki/GTD-UI) - Nicely display GTD related informations
- `core.neorgcmd` - undocumented module
