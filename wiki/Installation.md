<div align="center">

# Getting started with Neorg

Everything you need to know about organizing your life in Neovim.

</div>

Table of Contents:
- [Installing Neorg](#installation)
- [The concept of modules](#the-concept-of-modules)
- [Enabling our own modules](#enabling-our-own-modules)
- [Keybinds](#keybinds-in-neorg)
- [Logger configuration](#configuring-the-logger)
- [Hooking ourselves into the Neorg environment](#user-callbacks)

---

# Installation
Installing neorg is very simple. Here's how you do it using [packer](https://github.com/wbthomason/packer.nvim):
```lua
use { 'vhyrro/neorg', config = function()

	require('neorg').setup {}

end}
```

The above snippet sets up neorg with all its defaults. However, the defaults for neorg are "do nothing". This is because we need to explicitly tell neorg "hey, I want to use this functionality and that functionality" ourselves. This brings us swiftly on to how this functionality is represented: **modules**.

# The Concept of Modules
Modules are pieces of code that can be loaded and unloaded at will. This means someone can implement a bit of new functionality without having to rewrite a bunch of boilerplate code. Modules can be created by us (the core team) and by you, the community! They can interact with each other, bind themselves to keybinds and autocommands and they're even hotswappable!

What you need to know as the user is their naming convention. An example name for a module is `core.autocommands`, where 'core' is the category of the module and 'autocommands' is the actual name.

### Enabling our own modules
Neorg has several modules, a list of which can be found [here](https://github.com/vhyrro/neorg/wiki/Home#builtin-modules). The main ones you should worry about
are `core.defaults`, `core.norg.concealer` and `core.norg.dirman`. `core.defaults` provides all the main things you'd expect from neorg as a plugin, whilst `core.norg.concealer` is an
extension of the `core.norg` module and enhances your editing experience by using icons for certain text patterns rather than raw, boring text.
`core.norg.dirman` manages your Neorg workspaces so you can jump between them in just a few keypresses. To enable them, you'd do this:
```lua
use { 'vhyrro/neorg', config = function()

	require('neorg').setup {
		load = {
			["core.defaults"] = {},	-- Tells neorg to load the module called core.defaults with no extra data
			["core.norg.concealer"] = {}, -- Since this module isn't part of core.defaults, we can include it ourselves, like so
			["core.norg.dirman"] = {}, -- Loads the directory manager with no configuration
		}
	}

end}
```

That's how you define what modules you want.

### Metamodules
Metamodules are modules that exist solely for the purpose of batching together a bunch of other modules so you don't have to include each one individually. `core.defaults` is a prime example of a metamodule,
it batches all the things you might need into one easy-to-load module so you can get up and running with minimal hassle.

# Keybinds in Neorg
Keybinds are a pretty big topic - you must bind all keys yourself in the form of callbacks to the neorg environment. Sounds scary!
A list of all keybinds that Neorg currently provides can be found in its [corresponding document](https://github.com/vhyrro/neorg/wiki/User-Keybinds).
There you will be able to find a categorized list of available keys that you may want to bind alongside a megalist which you can copy and paste into your own
config and have everything up and running. Neorg used to enforce keybinds but after realizing that's a terrible design choice we have elected to do it this way
instead - no more spoonfeeding you keys!

# Configuring the Logger
Neorg comes with an inbuilt logger, which is a modification of [vlog.nvim](https://github.com/tjdevries/vlog.nvim). It can be configured like so:

```lua
use { 'vhyrro/neorg', config = function()

	require('neorg').setup {
		load = { ... },

		logger = {
		  -- Should print the output to neovim while running
		  use_console = true,

		  -- Should highlighting be used in console (using echohl)
		  highlights = true,

		  -- Should write to a file
		  use_file = true,

		  -- Any messages above this level will be logged.
		  level = "warn",

		  -- Level configuration
		  modes = {
			{ name = "trace", hl = "Comment", },
			{ name = "debug", hl = "Comment", },
			{ name = "info",  hl = "None", },
			{ name = "warn",  hl = "WarningMsg", },
			{ name = "error", hl = "ErrorMsg", },
			{ name = "fatal", hl = "ErrorMsg", },
		  },

		  -- Can limit the number of decimals displayed for floats
		  float_precision = 0.01,
		}
	}

end}
```

What you see above are the default options for the logger.

# User Callbacks
User Callbacks are ways to hook youself into and extend the Neorg environment to your heart's content.
You can read more about the topic [here](https://github.com/vhyrro/neorg/wiki/User-Callbacks).

# Configuring Individual Modules
Once you have acquainted yourself with all the information above, it's time you learn how to configure each module individually. This is explained in the [Configuring Modules](https://github.com/vhyrro/neorg/wiki/Configuring-Modules) section of the wiki. See you there!
