# Metamodules - an Introduction
In short, metamodules are special types of modules that can batch together a bunch of different modules into one easy-to-load group.
Neorg currently has one inbuilt metamodule - `core.defaults`, which houses all the default modules we would want to load into neorg.

### Creating a Metamodule
Creating a metamodule is insanely easy, since metamodules are just wrappers around existing modules. You can create them like this:
```lua
--[[
--	A test metamodule to showcase its capabilities
--]]

require('neorg.modules.base')

return neorg.modules.create_meta("my.modules", "some.submodule", "some.other.submodule", ...) -- Add as many modules here as you like
```

Yeah, seriously, that's all it takes! The `create_meta(name, ...)` function creates a regular module but overrides the `setup` and `unload` functions in order to autoload and auto-unload all the submodules we have defined.

To load it, just do:
```lua
require('neorg').setup {
	load = {
		["my.modules"] = {} -- Will autoload some.submodule and some.other.submodule
	}
}
```

### Disabling modules we don't care about
It's also possible to selectively disable any modules that we don't deem worthy of being part of our environment.
We can do it easily like so:
```lua
require('neorg').setup {
	load = {
		["core.defaults"] = { -- Metamodule that contains all the essential stuff a user can expect from neorg
			config = {
				disable = { "core.norg.qol.todo_items" } -- Disables these modules
			}
		}
	}
}
```

The above code snippet will load all modules that are part of the `core.defaults` metatable *apart* from `core.norg.qol.todo_items`, which is
a module responsible for operations related to TODO items.
