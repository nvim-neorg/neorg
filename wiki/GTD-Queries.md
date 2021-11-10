# GTD Queries module

## Summary
Get tasks, projects and useful informations for GTD

## Overview

Custom gtd queries, that respect the neorg GTD specs (`:h neorg-gtd-format`)

## Usage
### How to Apply
- To manually load the module, place this code in your Neorg setup:
  ```lua
  ["core.gtd.queries"] = {
     config = { -- Note that this table is optional and doesn't need to be provided
         -- Configuration here
     }
  }
  ```
  Consult the [configuration](#Configuration) section to see how you can configure `core.gtd.queries` to your liking.

### Configuration
No configuration provided
## Developer Usage
### Public API
This segment will detail all of the functions `core.gtd.queries` exposes. All of these functions reside in the `public` table.

- `starting_after_today`
- `get_end_project`
- `delete`
- `get_end_document_content`
- `modify`
- `diff_with_today`
- `get`
- `sort_by`
- `get_at_cursor`
- `update`
- `date_converter`
- `create`
- `add_metadata`

### Examples
#### Get all tasks and projets from buffer
```lua
local buf = 1 -- The buffer to query informations

local queries = module.required["core.gtd.queries"]

local tasks = queries.get("tasks", { bufnr = buf })
local projects = queries.get("projects", { bufnr = buf })

print(tasks, projects)
```


## Extra Info
### Version
This module supports at least version **0.0.8**.
The current Neorg version is **0.0.8**.

### Requires
- `core.norg.dirman` - undocumented module
- `core.queries.native` - undocumented module
- `core.integrations.treesitter` - undocumented module
