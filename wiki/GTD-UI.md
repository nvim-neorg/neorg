# GTD UI module

## Summary
Nicely display GTD related informations

## Overview

This module is like a sub-module for `norg.gtd.base` , exposing public functions to display nicely aggregated stuff, like tasks and projects.

## Usage
### How to Apply
- To manually load the module, place this code in your Neorg setup:
  ```lua
  ["core.gtd.ui"] = {
     config = { -- Note that this table is optional and doesn't need to be provided
         -- Configuration here
     }
  }
  ```
  Consult the [configuration](#Configuration) section to see how you can configure `core.gtd.ui` to your liking.

### Configuration
No configuration provided
## Developer Usage
### Public API
This segment will detail all of the functions `core.gtd.ui` exposes. All of these functions reside in the `public` table.

- `show_capture_popup`
- `show_views_popup`
- `edit_task`
- `goto_node`
- `display_contexts`
- `edit_task_at_cursor`
- `get_by_var`
- `display_today_tasks`
- `display_projects`
- `display_someday`
- `close_buffer`
- `toggle_details`
- `refetch_data_not_extracted`
- `display_waiting_for`
- `display_weekly_summary`

### Examples
None Provided

## Extra Info
### Version
This module supports at least version **0.0.8**.
The current Neorg version is **0.0.8**.

### Requires
- `core.ui` - undocumented module
- `core.keybinds` - undocumented module
- `core.norg.dirman` - undocumented module
- [`core.gtd.queries`](https://github.com/nvim-neorg/neorg/wiki/GTD-Queries) - Get tasks, projects and useful informations for GTD
- `core.integrations.treesitter` - undocumented module
- `core.mode` - undocumented module
