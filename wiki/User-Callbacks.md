<div align="center">

# User Callbacks

Hooking yourself directly into the Neorg environment

</div>

# What are User Callbacks?
User Callbacks are ways to react to certain events that Neorg broadcasts throughout the Neorg Environment.
Thanks to this it's possible to act upon changes to certain states and to further boost the extensibility of the neorg project.

Neorg provides the `neorg.callbacks` lua module, which is what handles the defining of callbacks.
Let's take a look at how we can inject some of our juicy code into Neorg:

```lua
local neorg_callbacks = require('neorg.callbacks')

neorg_callbacks.on_event("core.autocommands.events.bufenter", function(event, event_content)
	local log = require('neorg.external.log')

	log.warn("Entered a neorg buffer!")
end)
```

Simple enough, right? In fact as of right now `neorg.callbacks` only provides this single `on_event()` function
to be used by users. Now, whenever any sort of module broadcasts the `core.autocommands.events.bufenter` event
that broadcast will first be intercepted with our code and only then broadcast further. User Callbacks also catch
events sent via `neorg.events.send_event()`. The callback that we define has two parameters that it provides,
and they are as follows:
- `event` - the event that got broadcast, packed with every bit of metadata that that event had originally during
the broadcast.
- `event_content` - simply a shorthand for `event.content`, so you don't have to create aliases along the lines of:
	```lua
	local content = event.content
	```
	This QOL thing becomes more useful whenever an event exposes functions you can invoke, which we will explore
	in due time.

### Binding Keys with User Callbacks
`core.keybinds` - the module responsible for managing keys and notifying the rest of the environment
about events related to those keys, provides a special event called `core.keybinds.events.enable_keybinds`. This event
gets triggered whenever keys need to be bound or rebound in the Neorg environment - it signals a "ready" state of sorts
to the user that now is the time to bind your keys. The content of the event provides us with three functions: `map()`,
`map_to_mode()` and `map_event_to_mode()` - each of which provides a different level of abstraction. You should use these
functions rather than `vim.api.nvim_set_keymap()` because these functions also track which keys you've bound so far which is
crucial for Neorg Modes to function as intended - so please, use these funcs instead. I know I know, you really like using
core neovim functions, but bear with me here, it's important. Let's see an example of each function in use:

```lua
local neorg_callbacks = require('neorg.callbacks')

-- NEORG KEYBINDS

-- Keys for managing TODO items and setting their states
neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, content)

	if content.mode == "special-mode" then
		content.map('n', "<C-s>", ":w<CR>", { silent = true })
	end

	content.map_to_mode("special-mode", {
		n = {
			{ "<C-s>", ":w<CR>" }
		}
	}, { silent = true })

	content.map_event_to_mode("norg", {
		n = {
			{ "gtd", "core.norg.qol.todo_items.todo.task_done" },
			{ "gtu", "core.norg.qol.todo_items.todo.task_undone" },
			{ "gtp", "core.norg.qol.todo_items.todo.task_pending" },
			{ "<C-Space>", "core.norg.qol.todo_items.todo.task_cycle" }
		},
	}, { silent = true, noremap = true })

end)
```

- `map()` - the most "raw" function available. A wrapper around `vim.api.nvim_set_keymap()`. It's possible to not
supply the fourth argument. Note that this function does not have the "Neorg Mode" parameter, and hence it should be wrapped
in an `if` statement instead.
- `map_to_mode()` - higher level function, maps a set of keybinds only when a certain Neorg Mode is active.
- `map_event_to_mode()` - higher level function, maps a set of Neorg events to a certain Neorg Mode. The difference
between this function and the previous one is that the `rhs` parameter is not an entire neovim command but rather
a Neorg keybind. The actual final command will look like this: `:Neorg keybind <neorg mode supplied in first arg> %s<CR>`, where %s is the string the user provided.
