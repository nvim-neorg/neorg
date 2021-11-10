# The `core.defaults` Module

## Summary
Metamodule for storing the most necessary modules.

## Overview
This file contains all of the most important
modules that any user would want to have a "just works" experience.

## Usage
### How to Apply
- To manually load the module, place this code in your Neorg setup:
  ```lua
  ["core.defaults"] = {
     config = { -- Note that this table is optional and doesn't need to be provided
         -- Configuration here
     }
  }
  ```
  Consult the [configuration](#Configuration) section to see how you can configure `core.defaults` to your liking.

### Configuration
- `enable`
```lua
{ "core.autocommands", "core.neorgcmd", "core.keybinds", "core.mode", "core.norg.qol.todo_items", "core.norg.esupports", "core.norg.esupports.metagen", "core.integrations.treesitter", "core.norg.manoeuvre" }
```
## Developer Usage
### Public API
This segment will detail all of the functions `core.defaults` exposes. All of these functions reside in the `public` table.

No public functions exposed.

### Examples
None Provided

## Extra Info
### Version
This module supports at least version **0.0.8**.
The current Neorg version is **0.0.8**.

### Requires
This module does not require any other modules to operate.
