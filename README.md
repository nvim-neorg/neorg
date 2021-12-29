<!-- ttttt.txt g?? -->

<div align="center">

<img src="res/neorg.svg" width=300>

# Neorg

<a href="https://neovim.io"> ![Neovim](https://img.shields.io/badge/Neovim%200.6+-green.svg?style=for-the-badge&logo=neovim) </a>
<a href="https://discord.gg/T6EgTAX7ht"> ![Discord](https://img.shields.io/badge/discord-join-7289da?style=for-the-badge&logo=discord) </a>
<br>
<a href="https://www.buymeacoffee.com/vhyrro"> ![BuyMeACoffee](https://img.shields.io/badge/support-buy%20me%20a%20coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee) </a>
<a href="https://patreon.com/vhyrro"> ![Patreon](https://img.shields.io/badge/support-patreon-F96854?style=for-the-badge&logo=patreon) </a>
<br>
<a href="/LICENSE"> ![License](https://img.shields.io/badge/license-GPL%20v3-brightgreen?style=for-the-badge)</a>
<a href="#wip"> ![Status](https://img.shields.io/badge/status-WIP-informational?style=for-the-badge) </a>

_Your new life organization tool_

[Summary](#summary)
•
[Installation](#installation)
•
[Setup](#setup)
•
[Usage](#usage)
•
[Modules](#modules)
•
[Roadmap](#roadmap)
•
[Philosophy](#philosophy)
<br>
[GIFS](#gifs)
•
[FAQ](#faq)
•
[Contributing](#contributing)
•
[Credits](#credits)
•
[Support](#support)

</div>

## Summary

Neorg (_New_-_Organization_) is a tool designed to reimagine organization as you know it.

Grab some coffee, start writing some notes, let your editor handle the rest!

> Why do we need Neorg ?

There are currently projects designed to [clone org-mode from emacs](https://github.com/kristijanhusak/orgmode.nvim),
then what is the goal of this project?

Whilst those projects are amazing, it's simply not enough for us. We need our _own, better_ solution - one that will
surpass _every_ other text editor.

That's why we created _Neorg_.

_IMPORTANT_: Neorg is _alpha_ software. We consider it stable however be prepared for changes and potentially outdated documentation. We are advancing fast and keeping docs up-to-date would be very painful.

To know more about the philosophy of Neorg, go [here](#philosophy).

## Installation

Neorg requires at least `0.6+` to operate.
You can still use Neorg on `0.5.x`, however don't expect all modules to load properly.

You can install through your favorite plugin manager:

- [Packer](https://github.com/wbthomason/packer.nvim):

  ```lua
  use {
      "nvim-neorg/neorg",
      config = function()
          require('neorg').setup {
              ... -- check out setup part...
          }
      end,
      requires = "nvim-lua/plenary.nvim"
  }
  ```

- [Packer (with lazyloading)](https://github.com/wbthomason/packer.nvim):

  Want to lazy load? Turns out that can be rather problematic.
  You can use the `ft` key to load Neorg only upon entering a .norg file:

  ```lua
  use {
    "nvim-neorg/neorg",
    ft = "norg",
    after = { "nvim-treesitter" },  -- You may also specify Telescope
    config = function()
      -- setup neorg
      require('neorg').setup {
        ...
      }
    end
  }
  ```

  However, don't expect everything to work. You might need additional setups depending on how your lazyloading system is configured.

  Neorg practically lazy loads itself: only a few lines of code are run on startup, these lines check whether the current
  extension is `.norg`, if it's not then nothing else loads. You shouldn't have to worry about performance issues.

- [vim-plug](https://github.com/junegunn/vim-plug):

  ```vim
  Plug 'nvim-neorg/neorg' | Plug 'nvim-lua/plenary.nvim'
  ```

  You can put this initial configuration in your init.vim file:

  ```vim
  lua << EOF
  require('neorg').setup {
      " check out setup part...
  }
  EOF
  ```

## Setup

### Default modules

You can enable the default modules that we recommend you when using Neorg:

```lua

require('neorg').setup {
  load = {
    ["core.defaults"] = {}
  }
}
```

You can see [here](https://github.com/nvim-neorg/neorg/wiki#default-modules) which modules are automatically required when adding `core.defaults`

### Treesitter

_Be sure to have [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) installed on your system!_

To install it, you want to run this code snippet before you invoke
`require('nvim-treesitter.configs').setup()`:

```lua
local parser_configs = require('nvim-treesitter.parsers').get_parser_configs()

parser_configs.norg = {
    install_info = {
        url = "https://github.com/nvim-neorg/tree-sitter-norg",
        files = { "src/parser.c", "src/scanner.cc" },
        branch = "main"
    },
}

parser_configs.norg_meta = {
    install_info = {
        url = "https://github.com/nvim-neorg/tree-sitter-norg-meta",
        files = { "src/parser.c" },
        branch = "main"
    },
}

parser_configs.norg_table = {
    install_info = {
        url = "https://github.com/nvim-neorg/tree-sitter-norg-table",
        files = { "src/parser.c" },
        branch = "main"
    },
}
```

Then run `:TSInstall norg norg_meta norg_table`.

If you want the parser to be more persistent across different installations of your config make sure to set `norg`, `norg_meta` and `norg_table` as parsers in the `ensure_installed` table, then run `:TSUpdate`.

Here's an example config, yours will probably be different:

```lua
require('nvim-treesitter.configs').setup {
    ensure_installed = { "norg", "norg_meta", "norg_table", "haskell", "cpp", "c", "javascript", "markdown" },
    highlight = { -- Be sure to enable highlights if you haven't!
        enable = true,
    }
}
```

Having a rare occurence where the parser doesn't work instantly? Try running `:e`.

**Still not working**? Uh oh, you're stepping on muddy territory. There are several reasons why a parser
may not work right off the bat, however most commonly it's because of plugin loading order.

Neorg needs `nvim-treesitter` to be up and running before it starts adding colours to highlight groups.

Not using packer? Make sure that Neorg's `setup()` gets called after `nvim-treesitter`'s setup.

It's a bit hacky - it will unfortunately stay this way until we get first-class support in the `nvim-treesitter` repository.
Sorry!

## Usage

We recommend reading the [spec](docs/NFF-0.1-spec.md) and familiarizing yourself with the new format 🥳

You can even view a summary directly in your neovim instance, by doing `:h neorg`

Simply drop into a `.norg` file and start typing!

Or you can require the `core.norg.dirman` module, that'll help you manage workspaces:

```lua
require('neorg').setup {
  load = {
    ...
    ["core.norg.dirman"] = {
      config = {
        workspaces = {
          my_workspace = "~/neorg"
        }
      }
    }
    ...
  }
}
```

And just do `:NeorgStart`, and it'll open your last (or only) workspace !

Changing workspaces is easy, just do `Neorg workspace ...`

> It works now, what are the next steps ?

We recommend you add some core modules that can greatly improve your experience, such as 

- Setting up a completion engine (`core.norg.completion`)
- Using the default keybinds provided by Neorg (`core.norg.keybinds`)
- Using the concealer module, that will use icons where possible (`core.norg.concealer`)

Stay on board, we're now showing you how to add modules !

## Modules

As you surely saw previously, we loaded `core.defaults`, and recommended you loading `core.norg.dirman`.

They are called a module ! And guess what ? As time passes, we provide more and more modules to help you manage your life !

To require a module, just do:

```lua
require('neorg').setup {
  load = {
    ...
    -- Require the module with the default configurations for it
    ["your.required.module"] = { },
    -- Require the module, and override the configurations (with the "config" table)
    ["your.required.module"] = { }
      config = {
        some_option = true
      }
    }
    ...
  }
}
```

For more information about what is a module, check out [here](https://github.com/nvim-neorg/neorg/wiki/Installation#the-concept-of-modules).

To know which configurations are provided by default for a module, just click on their link: you'll go to the module page in the [Wiki](https://github.com/nvim-neorg/neorg/wiki).

### Default Modules

The default modules are automagically required when you require `core.defaults`, handy !

You can view a list of them [here](https://github.com/nvim-neorg/neorg/wiki#default-modules).

<!-- TODO: Use docgen to generate this automatically -->

### Core Modules

Neorg comes with some cool modules to help you manage your notes.

Feel free to try by adding them to your Neorg setup.

<!-- TODO: Use docgen to generate this automatically -->

| Module name                                                                     | Description                                                                 |
| :------------------------------------------------------------------------------ | :-------------------------------------------------------------------------- |
| [`core.presenter`](https://github.com/nvim-neorg/neorg/wiki/Core-Presenter)     | Neorg module to create gorgeous presentation slides.                        |
| [`core.norg.completion`](https://github.com/nvim-neorg/neorg/wiki/Completion)   | A wrapper to interface with several different completion engines.           |
| [`core.norg.concealer`](https://github.com/nvim-neorg/neorg/wiki/Concealer)     | Enhances the basic Neorg experience by using icons instead of text.         |
| [`core.norg.journal`](https://github.com/nvim-neorg/neorg/wiki/Journal)         | Easily create files for a journal.                                          |
| [`core.gtd.base`](https://github.com/nvim-neorg/neorg/wiki/Getting-Things-Done) | Manages your tasks with Neorg using the Getting Things Done methodology.    |
| [`core.norg.dirman`](https://github.com/nvim-neorg/neorg/wiki/Dirman)           | This module is be responsible for managing directories full of .norg files. |

### External Modules

Users can contribute and create their own modules for Neorg.

To use them, just download the plugin with your package manager, for instance with Packer:

```lua
use {
    "nvim-neorg/neorg",
    requires = "the.module.name",
    ...
}
```

After that it's as easy as loading a module normally:

```lua
require('neorg').setup {
  load = {
    ...
    ["the.module.name"] = { },
  }
}
```

This is a list of external modules:

| Module name                                                                        | Description                                                                   |
| :--------------------------------------------------------------------------------- | :---------------------------------------------------------------------------- |
| [`utilities.gtd-project-tags`](https://github.com/esquires/neorg-gtd-project-tags) | Provides a view of tasks grouped with a project tag. Requires `core.gtd.base` |

## Roadmap

We track a high-level roadmap, so that you can know what to expect. Just do `:h neorg-roadmap`.

To know exactly what's being worked on, just check out the [PR's](https://github.com/nvim-neorg/neorg/pulls).

## Philosophy

We think of Neorg as a plugin that will give you all the bragging rights for using Neovim. Here's how we plan to do it:

1. Revise the org format: we want it simple, very extensible, unambiguous. Will make you feel right at home. Org and markdown have several flaws, but the most
   notable one is the requirement for **complex parsers**.
   I really advise checking some writeups out on how bad it can get at times.
   What if we told you it's possible to alleviate those problems, all whilst keeping that familiar feel?
   Enter the .norg file format, whose [base spec](docs/NFF-0.1-spec.md) is practically complete.
   The cross between all the best things from org and the best things from markdown, revised and merged into one.

2. Keybinds that _make sense_: vim's keybind philosophy is unlike any other, and we want to keep that vibe.
   Keys form a "language", one that you can speak, not one that you need to learn off by heart.

3. Infinite extensibility: no, that isn't a hyperbole. We mean it. Neorg is built upon an insanely modular and
   configurable backend - keep what you need, throw away what you don't care about. Use the defaults or change 'em.
   You are in control of what code runs and what code doesn't run!

4. Logic: everything has a reason, everything has logical meaning. If there's a feature, it's there because it's necessary, not because
   two people asked for it.

## GIFS

## FAQ

## Contributing

## Credits

Massive shoutouts go to the people who supported the project, and help out in creating a good user experience! These are:

- [vhyrro](https://github.com/vhyrro)
- [mrossinek](https://github.com/mrossinek)
- [danymat](https://github.com/danymat)
- [Binx](https://github.com/Binx-Codes/)
- [bandithedoge](https://github.com/bandithedoge)

## Support

A word from the creator, Vhyrro:

> Love what I do? Want to see more get done faster? Want to support future projects of mine? Any sort of support is always
> heartwarming and fuels the urge to keep going :heart:. You can support me here:

- [Buy me a coffee!](https://buymeacoffee.com/vhyrro)
- [Support on LiberaPay](https://liberapay.com/vhyrro)
- [Donate directly via paypal](https://paypal.me/ewaczupryna?locale.x=en_GB)
- [Support me on Patreon](https://patreon.com/vhyrro)
- Donate to my monero wallet: `86CXbnPLa14F458FRQFe26PRfffZTZDbUeb4NzYiHDtzcyaoMnfq1TqVU1EiBFrbKqGshFomDzxWzYX2kMvezcNu9TaKd9t`
- Donate via bitcoin: `bc1q4ey43t9hhstzdqh8kqcllxwnqlx9lfxqqh439s`

<!--
![Usage Showcase](https://user-images.githubusercontent.com/13149513/125274594-ef23c900-e32f-11eb-83dd-88627a038e01.gif)

### Manage Your Life with Neovim-inspired Keybinds
Keybinds that make logical sense. Simply think, don't remember.

<img src="https://user-images.githubusercontent.com/76052559/132091379-845bf06d-7516-4c28-b32d-77b9734a44fe.gif">

---

### Jump To The Most Important Directories with Workspaces
Teleport to your favourite locations right away.


</div>

<div align="center">
<img src="https://user-images.githubusercontent.com/13149513/125272567-cf8ba100-e32d-11eb-821d-f43f768570fb.gif">
<img src="https://user-images.githubusercontent.com/13149513/125272579-d2869180-e32d-11eb-936b-1601086d0c73.gif">
</div>

---

<div align="center">

### Configure Everything - Literally
Experience the power and configurability of Neorg's backend through modules and events.
<br>
Select only the code you want - throw everything else away.

<img src="https://user-images.githubusercontent.com/13149513/125273662-fc8c8380-e32e-11eb-873f-b6dab3ba0c2e.gif">

</div>

---

<div align="center">

### TreeSitter Powered Editing
Feel more accurate edits thanks to Neorg's deeper understanding of your documents with Treesitter

<img src="https://user-images.githubusercontent.com/76052559/132091729-6814a796-21a9-43af-a8f1-df7f44d1928b.gif">

</div>


# :keyboard: Keybinds
Neorg comes with no keys bound by default. If you want to use all the default keys, you may want to modify the `core.keybinds`'s configuration
to generate them for you, here's how you would do it (note that this code snippet is an extension of the [installation](#wrench-installation) snippet):
```lua
use {
    "nvim-neorg/neorg",
    config = function()
        require('neorg').setup {
            -- Tell Neorg what modules to load
            load = {
                ["core.defaults"] = {}, -- Load all the default modules
                ["core.keybinds"] = { -- Configure core.keybinds
                    config = {
                        default_keybinds = true, -- Generate the default keybinds
                        neorg_leader = "<Leader>o" -- This is the default if unspecified
                    }
                },
                ["core.norg.concealer"] = {}, -- Allows for use of icons
                ["core.norg.dirman"] = { -- Manage your directories with Neorg
                    config = {
                        workspaces = {
                            my_workspace = "~/neorg"
                        }
                    }
                }
            },
        }
    end,
    requires = "nvim-lua/plenary.nvim"
}
```

You may actually want to change your keybinds though! Changing keybinds is a rather trivial task.
The wiki entry for keybinds can be found [here](https://github.com/nvim-neorg/neorg/wiki/User-Keybinds). It'll tell you the ins and outs of what you need to do :)

# :notebook: Consult The Wiki
The wiki is the go-to place if you need answers to anything Neorg-related. Usage, Keybinds, User Callbacks, Modules, Events?
It's all there, so we recommend you seriously go [read it](https://github.com/nvim-neorg/neorg/wiki)!

# :computer: Contributing
Contributions are always welcome and will always be welcome. You can check [CONTRIBUTING.md](docs/CONTRIBUTING.md) if you wanna find out more.
Have a cool idea? Want to implement something, but don't know where to start? I'm always here to help! You can always create an issue or join the discord
and chat there.

# :camera: Extra GIFs
### Language Injection
Get syntax highlighting for any language supported by NeoVim.
Neorg will use treesitter first, falling back to Vim regex for languages not supported by treesitter seamlessly.

![Injection](https://user-images.githubusercontent.com/13149513/125274035-5f7e1a80-e32f-11eb-8de3-060b6e752185.gif)

### Smort Syntax
Thanks to TreeSitter we can achieve a surprising amount of precision.

![Trailing Modifier Showcase](https://user-images.githubusercontent.com/13149513/125274133-79b7f880-e32f-11eb-86c3-c06f1484b685.gif)
![Comments](https://user-images.githubusercontent.com/13149513/125274156-80467000-e32f-11eb-935c-a65460b3fc61.gif)

### Completion
Neorg uses both TreeSitter and nvim-compe in unison to provide
contextual completion based on your position in the syntax tree.

![Completion](https://user-images.githubusercontent.com/13149513/125274303-a835d380-e32f-11eb-9a75-a2a4eb421a61.gif)
![Code Tag Completion](https://user-images.githubusercontent.com/13149513/125274336-aff57800-e32f-11eb-88e0-dfd9895d5d26.gif)

-->
