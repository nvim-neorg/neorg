<div align="center">

# Setting up Neorg

A guide on configuring Neorg.

</div>

> [!NOTE]
> If you're just getting started and have no idea why and where to use Neorg,
> feel free to check out the [Getting Started](#) page (link defunct, will be added soon).

## Where do I begin?

Neorg, being a large organizational tool for many different types of people, needs to be
extensible and highly configurable. It's for this reason that setting it up takes slightly
longer than your average Neovim plugin.

Because of this, learning to navigate the Neorg wiki as well as learning the basics of how the system
works will get you a very long way in making Neorg your own.

This guide assumes that you've completed the initial [setup process](https://github.com/nvim-neorg/neorg?tab=readme-ov-file#-installation) successfully and without errors.

## Default Setup

The default configuration looks like follows:
```lua
require("neorg").setup()
```

This code initializes Neorg with the *default options*. In practice it's equivalent to the following:
```lua
require("neorg").setup({
    load = {
        ["core.defaults"] = {},
    }
})
```

This immediately introduces you to an important concept: **modules**.

The entire core of Neorg is modular, that is, all functionality is isolated into bits
of code. Every module has its own configuration options, its own behaviours,
its own keymaps, etc.

`core.defaults` is a special type of module called a metamodule - it acts as a quick way to load a bunch of other modules
at once. If you'd like to see what sort of modules `core.defaults` loads, check out [this wiki entry](https://github.com/nvim-neorg/neorg/wiki#default-modules).

## Configuring Parts of Neorg

By default, Neorg comes with the bare experience. It loads modules that are critical for Neorg to function
properly. This workflow is mainly tailored for people who use Neorg to write documentation in the Norg file format, but nothing more than that.

If you're using Neorg to write notes or to perform time-tracking tasks you may want to load *extra modules*
that provide more functionality than the default.

These extra modules are listed [in a separate heading in the wiki](https://github.com/nvim-neorg/neorg/wiki#other-modules). Feel free to check some of them out!
They all have documentation and their behaviours are explained.

## Loading New Modules

The most common module people set up is the concealer module - it converts our
notes from regular plaintext to beautified plaintext thanks to its use of
icons. If you click on the module name in the wiki, it'll take you to [this
page](https://github.com/nvim-neorg/neorg/wiki/Concealer).

To load the module, we use the full path of the module (in this case `core.concealer`).
Let's adapt our configuration:
```lua
require("neorg").setup({
    load = {
        ["core.defaults"] = {},
        ["core.concealer"] = {}, -- We added this line!
    }
})
```

If you restart Neovim and enter a `test.norg` file with the following content:
```norg
* Hello from Neorg!
```
You should see that the heading has a nice icon!

A decent chunk of modules require no configuration and work out of the box. Feel free to try as
many as you like!

### Dependence on Neovim Options

If you carefully read the [overview page for the concealer](https://github.com/nvim-neorg/neorg/wiki/Concealer#overview),
you'll notice that the concealer respects the Neovim `conceallevel` and `concealcursor` options.

If possible, Neorg will not mess with your Neovim options. Check out the help pages for both options
and tweak them as you see fit. For example, `vim.opt.conceallevel = 3` will cause many elements of the document
like the asterisks around `*bold*` words to disappear!

## Configuring Individual Modules

If you had read onwards in the concealer's page you may have noticed a [configuration section](https://github.com/nvim-neorg/neorg/wiki/Concealer#configuration).
This section details all of the possible configuration options as well as their descriptions. Click around and see what you can find!

Continuing with our concealer example, let's say we wanted to change the `icon_preset` setting.
The documentation tells us this option is a string, and that its default value is `"basic"`.

To configure the module, let's extend our configuration code:
```lua
require("neorg").setup({
    load = {
        ["core.defaults"] = {},
        ["core.concealer"] = {
            config = { -- We added a `config` table!
                icon_preset = "varied", -- And we set our option here.
            },
        },
    }
})
```

Notice that, to configure a module, we first provide a `config` table, and then all of our configuration inside!

If you save, quit and re-enter Neovim, the concealer should now use a completely different set of icons than it did before!
