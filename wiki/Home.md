<div align="center">

# Welcome to the neorg wiki!

Want to know how to properly use neorg? Your answers are contained here.

</div>

#### Table of contents:
- [I want to know how to use Neorg](#using-neorg)
- [I want to develop for Neorg](#developing-for-neorg)
- [I want to know how to use the inbuilt modules](#builtin-modules)

# Using Neorg
At first configuring Neorg might be rather scary. I have to define what modules I want to use in the `require('neorg').setup()` function? I don't even know what the default available values are.
Don't worry, an installation guide is present [here](https://github.com/vhyrro/neorg/wiki/Installation), so go ahead and read it!

# Developing for Neorg
Neorg is a very big and powerful tool behind the scenes - way bigger than it may initally seem.
Modules are its core foundation, and building modules is like building lego bricks to form a massive structure!
There's a whole tutorial dedicated to making modules [right here](https://github.com/vhyrro/neorg/wiki/Creating-Modules).
There everything you need will be explained - think of it as a walkthrough.

# Builtin Modules
Neorg comes with its own builtin modules to make development easier. Below is a list of all currently implemented builtin modules that are worth mentioning:
- [`core.autocommands`](https://github.com/vhyrro/neorg/wiki/Autocommands) - a module for wrapping events around autocommands
- [`core.keybinds`](https://github.com/vhyrro/neorg/wiki/Keybinds) - a module for binding events to keybinds
- [`core.neorgcmd`](https://github.com/vhyrro/neorg/wiki/Neorg-Command) - a module for interacting with the `:Neorg` command
- [`core.norg.concealer`](https://github.com/vhyrro/neorg/wiki/Concealing#api-functions) - beautifies your text editing experience by using sleek icons in place of certain patterns of text
- [`core.norg.dirman`](https://github.com/vhyrro/neorg/wiki/Dirman) - manages your directories as workspaces that you can easily jump to
- [`core.highlights`](https://github.com/vhyrro/neorg/wiki/Custom-Highlights#api-calls-for-corehighlights) - manages Neorg highlight groups and their colours.
