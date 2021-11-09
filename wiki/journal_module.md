# Journal module for neorg

## Summary
Easily create files for a journal

## Overview
How to use this module:
This module creates four commands.
- `Neorg journal today`
- `Neorg journal yesterday`
- `Neorg journal tomorrow`
With this commands you can open the config files for the dates.

- `Neorg journal custom`
This command requires a date as an argument.
The date should have to format yyyy-mm-dd.

## Usage
### How to Apply
- To manually load the module, place this code in your Neorg setup:
  ```lua
  ["core.norg.journal"] = {
     config = { -- Note that this table is optional and doesn't need to be provided
         -- Configuration here
     }
  }
  ```
  Consult the [configuration](#Configuration) section to see how you can configure `core.norg.journal` to your liking.

### Configuration
- `journal_folder`
```lua
"/journal/"
```
- `use_folders`
```lua
true
```
## Developer Usage
### Public API
This segment will detail all of the functions `core.norg.journal` exposes. All of these functions reside in the `public` table.

No public functions exposed.

### Examples
None Provided

## Extra Info
### Version
This module supports at least version **0.1**.
The current Neorg version is **0.0.8**.

### Requires
- `core.norg.dirman` - undocumented module
- `core.keybinds` - undocumented module
- `core.neorgcmd` - undocumented module
