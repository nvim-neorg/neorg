<div align="center">

# All the keybinds

</div>

This document contains information about all the keybinds that are mappable by Neorg and which modules
contain them. It will also show code snippets to set/override those keybinds.

This document will grow as Neorg grows. The format for each entry is as follows:

## A General Description
Information about the module's name and some extra info.

### Keybinds

`<some neorg mode>`:
- `<some keybind>` - \<expanded abbreviation\> - \<description\>. \<event_name\>
- `<some other keybind>` - \<expanded abbreviation\> - \<description\>. \<event_name\>

# Table of Contents
- [Quickstart](#quickstart)
- [Managing TODO Items](#managing-todo-items)
- [Keybind Megalist](#keybind-megalist)


### Quickstart
The recommended way of binding keys is as follows:
- Inside of your Neorg configuration, which may look something like:
```lua
use { 'vhyrro/neorg', config = function()

	require('neorg').setup {
		load = {
			["core.defaults"] = {},	-- Tells Neorg to load the module called core.defaults with no extra data
			["core.norg.concealer"] = {} -- Since this module isn't part of core.defaults, we can include it ourselves, like so
		}
	}

end}
```

Add a **post-init hook**, which will call the function you give it _after_ Neorg knows it has entered a .norg file and _before_
any modules are loaded. To add a post-init hook, you may alter your configuration as such:
```lua
use { 'vhyrro/neorg', config = function()

	require('neorg').setup {
		load = {
			["core.defaults"] = {},	-- Tells neorg to load the module called core.defaults with no extra data
			["core.norg.concealer"] = {} -- Since this module isn't part of core.defaults, we can include it ourselves, like so
		},

		hook = function()
			-- The code that we will showcase below goes here
		end
	}

end}
```

- Make sure you don't have `core.keybinds` configured to autogenerate keybindings. This can be achieved by setting its `default_keybinds` config
option to false or by simply not providing any configuration.
- Copy and paste the [Keybind Megalist](#keybind-megalist) into the `hook` function, or alternatively source a seperate
lua file containing the Keybind Megalist code.

If you want to learn more, please read the entry in the [User Callbacks](https://github.com/vhyrro/neorg/wiki/User-Callbacks#binding-keys-with-user-callbacks)
section of the wiki - you can find an in-depth explanation of all the features regarding keybinds that Neorg provides there.

<br>

---
---

<br>

# Managing Todo Items
The module that is responsible for managing TODO items is `core.norg.qol.todo_items`.
### Keybinds
`norg`:
- `gtd` - _g t(ask) d(one)_, marks a task as done. *Name: `todo.task_done`*
- `gtu` - _g t(ask) u(ndone)_, marks a task as undone. *Name: `todo.task_undone`*
- `gtp` - _g t(ask) p(ending)_, marks a task as pending. *Name: `todo.task_pending`*
- `<C-Space>` - \<no special meaning\>, toggles between all the task states. *Name: `todo.task_cycle`*

<br>

---
---

<br>

# Keybind Megalist
This is a massive code block that you can easily copy and paste into any configuration and be up and running with all the recommended default keybinds and features that neorg provides:
```lua
-- This sets the leader for all Neorg keybinds. It is separate from the regular <Leader>,
-- And allows you to shove every Neorg keybind under one "umbrella".
local neorg_leader = "<Leader>" -- You may also want to set this to <Leader>o for "organization"

-- Require the user callbacks module, which allows us to tap into the core of Neorg
local neorg_callbacks = require('neorg.callbacks')

-- Listen for the enable_keybinds event, which signals a "ready" state meaning we can bind keys.
-- This hook will be called several times, e.g. whenever the Neorg Mode changes or an event that
-- needs to reevaluate all the bound keys is invoked
neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybinds)

	-- Map all the below keybinds only when the "norg" mode is active
	keybinds.map_event_to_mode("norg", {
		n = { -- Bind keys in normal mode

			-- Keys for managing TODO items and setting their states
			{ "gtd", "core.norg.qol.todo_items.todo.task_done" },
			{ "gtu", "core.norg.qol.todo_items.todo.task_undone" },
			{ "gtp", "core.norg.qol.todo_items.todo.task_pending" },
			{ "<C-Space>", "core.norg.qol.todo_items.todo.task_cycle" }

		},
	}, { silent = true, noremap = true })

end)
```
