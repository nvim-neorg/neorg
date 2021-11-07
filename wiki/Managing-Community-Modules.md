# Publishing Your own Modules for Neorg

### Pushing our Own Module to GitHub
Pushing code to and from GitHub is very simple - you just need to format your module correctly. Let's begin!

First, make sure your code follows a structure similar to this:

```
<your module repo>
└── lua
    └── neorg
        └── modules
            └── category
                └── optional_subcategory
                    └── module_name
                        └── module.lua
```

Each module that is pullable from github follows this format - it's the same format as a regular Lua plugin for Neovim.
Inside the `lua/neorg` directory you want to have a `modules` directory, this is where you can place all of your favourite modules.

That's it! You can push your module to github and have a great time. Now we need to pull it.

### Pulling our Module
Pulling our module is incredibly simple, as all we have to do is grab the module with our favourite package
manager!

This is how you might wanna do it with [Packer](https://github.com/wbthomason/packer.nvim):

```lua
use {
	"vhyrro/neorg",
	<other stuff>,
	requires = "our/module"
}
```

After that it's as easy as loading our module normally:
```lua
config = function()
	require('neorg').setup {
		load = {
			["core.defaults"] = {},
			<whatever else you may have>,
			["utilities.dateinserter"] = {
				config = { ... } -- Configure it as if it were a regular module!
			}
		}
	}
end
```
