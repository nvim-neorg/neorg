<!-- ttttt.txt g?? -->

<div align="center">

<img src="res/neorg.svg" width=300>

# Neorg - An Organized Future

<a href="https://neovim.io"> ![Neovim](https://img.shields.io/badge/Neovim%200.6+-brightgreen?style=for-the-badge) </a>
<a href="https://discord.gg/T6EgTAX7ht"> ![Discord](https://img.shields.io/badge/discord-join-7289da?style=for-the-badge&logo=discord) </a>
<a href="/LICENSE"> ![License](https://img.shields.io/badge/license-GPL%20v3-brightgreen?style=for-the-badge)</a>
<a href="#wip"> ![Status](https://img.shields.io/badge/status-WIP-informational?style=for-the-badge) </a>

Your New Life Organization Tool, all in Lua

[Summary](#summary)
•
[Showcase](#showcase)
•
[Installation](#installation)
•
[Setup](#setup)
•
[Usage](#usage)
<br>
[Modules](#modules)
•
[Roadmap](#roadmap)
•
[Philosophy](#philosophy)
•
[FAQ](#faq)

</div>

<div align="center">

<br>

## Summary

</div>

Neorg (_Neo_ - new, _org_ - organization) is a tool designed to reimagine organization as you know it.
Grab some coffee, start writing some notes, let your editor handle the rest!

### Why do we need Neorg?

There are currently projects designed to [clone org-mode from emacs](https://github.com/kristijanhusak/orgmode.nvim),
then what is the goal of this project?

Whilst those projects are amazing, it's simply not enough for us. We need our _own, **better**_ solution -
one that will surpass _every_ other text editor. It's through our frustration of no native solution for Neovim
and inconsistencies in the most popular markup formats that Neorg was born.

To learn more about the philosophy of the project check the [philosophy](#philosophy) section.

###### :exclamation: **IMPORTANT**: Neorg is _alpha_ software. We consider it stable however be prepared for changes and potentially outdated documentation. We are advancing fast and while we are doing our best to keep the documentation up-to-date, this may not always be possible to the full extent.

## 🌟 Showcase

<details>
<summary>A .norg file:</summary>
  <img width="700" alt="Showcase image of a Neorg document" src="https://user-images.githubusercontent.com/5306901/147649564-6f41e008-b292-4a67-84ab-82e73bc71890.png">
</details>

<details>
<summary>Concealing module enabled:</summary>
  <img width="700" alt="Image of a Neorg document with the concealer module enabled." src="https://user-images.githubusercontent.com/5306901/147649784-5654009e-c4aa-4f2b-8e30-571578a313b6.png">
</details>

<details>
<summary>Playing around with our unique syntax elements:</summary>
  We also use some special keybinds to toggle our TODO items :)

  ![Showcase of our Keybinds in action](https://user-images.githubusercontent.com/5306901/147650852-de6b2542-39c4-44c6-a228-ded867a71d4e.gif)
</details>

<details>
<summary>Treesitter powered editing:</summary>

  ![Treesitter powered editing](https://user-images.githubusercontent.com/5306901/147652347-80daa0db-f5d5-46e7-b553-2922553c2c78.gif)
</details>

<details>
<summary>Manage your tasks and projects with the GTD module:</summary>

  - See your current projects

  ![See your current projects](https://user-images.githubusercontent.com/5306901/147652840-c8201380-9ce1-428c-8ce3-320dad5592c1.gif)

  - Create a new task

  ![Create a new task](https://user-images.githubusercontent.com/5306901/147653241-e8d2742c-354c-49e4-bad0-7091451c6628.gif)

  - Add information to your tasks, and jump to them quickly

  ![Add information to your tasks, and jump to them quickly](https://user-images.githubusercontent.com/5306901/147653650-a4a27c59-1213-4307-b3fc-c0a0bfefaa9b.gif)

  And much more...

</details>

<details>
  <summary>Powerpoint-like presentations in Neovim with the presenter module:</summary>

  ![Powerpoint-like presentations in Neovim with the presenter module](https://user-images.githubusercontent.com/5306901/147654155-c2aa728a-5c2b-4813-b3e2-fbf7e2ffd2a2.gif)
</details>

<details>
  <summary>Get syntax highlighting for any language supported by Neovim:</summary>

  ![Get syntax highlighting for any language supported by Neovim](https://user-images.githubusercontent.com/5306901/147657014-68573df8-0e43-4a8b-bb81-0db1c80cbbd8.gif)
</details>
</details>

<details>
  <summary>Get completion for various items in Neorg:</summary>

  ![Get completion for various items in Neorg](https://user-images.githubusercontent.com/5306901/147657095-aa51a609-5bc2-4aa4-9687-bdda6ef48860.gif)
</details>

## Installation

Neorg requires at least Neovim 0.6+ to operate.
You can still use Neorg on `0.5.x`, however don't expect all modules to load properly.

You can install it through your favorite plugin manager:

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

  Want to lazy load? Know that you'll have to jump through some hoops and hurdles to get
  it to work perfectly.
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

  Although it's proven to work for a lot of people, you might need additional setups depending on how your lazyloading system is configured.

  One important thing to ask yourself is: "is it really worth it?".
  Neorg practically lazy loads itself: only a few lines of code are run on startup, these lines check whether the current
  extension is `.norg`, if it's not then nothing else loads. You shouldn't have to worry about performance issues when it comes to startup, but
  hey, you do you :)

- [vim-plug](https://github.com/junegunn/vim-plug):

  ```vim
  Plug 'nvim-neorg/neorg' | Plug 'nvim-lua/plenary.nvim'
  ```

  You can then put this initial configuration in your `init.vim` file:

  ```vim
  lua << EOF
  require('neorg').setup {
      " check out setup part...
  }
  EOF
  ```

## Setup

You've got the basic stuff out the way now, but wait! That's not all. You've installed Neorg - great! Now you have to configure it.
By default, Neorg does nothing, and gives you nothing. You must tell it what you care about!

### Default modules

Neorg runs on _modules_, which are discussed and explained in more depth later on.
Each module provides a single bit of functionality - they can then be stacked together to form
the entire Neorg environment.

The most common module you'll find is the `core.defaults` module, which is basically a "load all features" switch.
It gives you the full experience out of the box.

The code snippet to enable all default modules is very straightforward:

```lua
require('neorg').setup {
    load = {
        ["core.defaults"] = {}
    }
}
```

You can see [here](https://github.com/nvim-neorg/neorg/wiki#default-modules) which modules are automatically required when adding `core.defaults`.

### Treesitter

###### _Be sure to have [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) installed on your system for this step!_

Neorg parsers don't come out of the box with `nvim-treesitter` yet.
To set up Neorg's parsers, you want to run this code snippet **before** you invoke `require('nvim-treesitter.configs').setup()`:

```lua
local parser_configs = require('nvim-treesitter.parsers').get_parser_configs()

parser_configs.norg = {
    install_info = {
        url = "https://github.com/nvim-neorg/tree-sitter-norg",
        files = { "src/parser.c", "src/scanner.cc" },
        branch = "main"
    },
}

-- These two are optional, but provide syntax highlighting
-- for Neorg tables and the @document.meta tag
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

If you're on Mac and have compilation errors when doing `:TSInstall`, check out this [fix](https://github.com/nvim-neorg/neorg/issues/74#issuecomment-906627223).
It's a bit hacky - it will unfortunately stay this way until we get first-class support in the `nvim-treesitter` repository.
Sorry!

## Usage

We recommend reading the [spec](docs/NFF-0.1-spec.md) and familiarizing yourself with the new format!
You can even view a summary directly in your neovim instance by running `:h neorg` if you don't like reading a lot.

Next step is to simply drop into a .norg file and start typing away!

A good first step is to require the `core.norg.dirman` module, it'll help you manage workspaces.
Workspaces are basically isolated directories that you can jump between:

```lua
require('neorg').setup {
    load = {
        ["core.defaults"] = {},
        ["core.norg.dirman"] = {
            config = {
                workspaces = {
                    work = "~/notes/work",
                    home = "~/notes/home",
                }
            }
        }
    }
}
```

Changing workspaces is easy, just do `:Neorg workspace work`, where `work` is the name of your workspace.
Note that `:Neorg` is only available when the Neorg environment is loaded, i.e. when you're
in a .norg file or have loaded a .norg file already in your Neovim session.

If the Neorg environment isn't loaded you'll find a `:NeorgStart` command which will launch Neorg and pop
you in to your last (or only) workspace.

> It works, cool! What are the next steps?

We recommend you add some core modules that can greatly improve your experience, such as:

- Setting up a completion engine (`core.norg.completion`)
- Using the concealer module to enable icons (`core.norg.concealer`)

## Modules

As you surely saw previously, we loaded `core.defaults`, and recommended that you load `core.norg.dirman`.
Sooo, what are they exactly? We'll give you a brief explanation.

Modules are basically isolated bits of code that provide a specific subset of features. They can be docked in
to the environment at any time and can be essentially stacked together like lego bricks!

To require a module, just do:

```lua
require('neorg').setup {
    load = {
        -- Require the module with the default configurations for it
        ["your.required.module"] = {},

        -- Require the module, and override the configurations (with the "config" table)
        ["your.required.module"] = {
            config = {
                some_option = true
            }
        }
    }
}
```

As always, for a little more info you can consult the wiki page [here](https://github.com/nvim-neorg/neorg/wiki/Installation#the-concept-of-modules).

To know which configurations are provided by default for a module, just click on their link: you'll go to the module page in the [wiki](https://github.com/nvim-neorg/neorg/wiki).

### Core Modules

Neorg comes with some cool modules to help you manage your notes.

Feel free to try by adding them to your Neorg setup.

<!-- TODO: Use docgen to generate this automatically -->

<details>
<summary>List of Core Modules:</summary>

| Module name                                                                     | Description                                                                 |
| :------------------------------------------------------------------------------ | :-------------------------------------------------------------------------- |
| [`core.presenter`](https://github.com/nvim-neorg/neorg/wiki/Core-Presenter)     | Neorg module to create gorgeous presentation slides.                        |
| [`core.norg.completion`](https://github.com/nvim-neorg/neorg/wiki/Completion)   | A wrapper to interface with several different completion engines.           |
| [`core.norg.concealer`](https://github.com/nvim-neorg/neorg/wiki/Concealer)     | Enhances the basic Neorg experience by using icons instead of text.         |
| [`core.norg.journal`](https://github.com/nvim-neorg/neorg/wiki/Journal)         | Easily create files for a journal.                                          |
| [`core.gtd.base`](https://github.com/nvim-neorg/neorg/wiki/Getting-Things-Done) | Manages your tasks with Neorg using the Getting Things Done methodology.    |
| [`core.norg.dirman`](https://github.com/nvim-neorg/neorg/wiki/Dirman)           | This module is be responsible for managing directories full of .norg files. |
| [`core.norg.qol.toc`](https://github.com/nvim-neorg/neorg/wiki/Qol-Toc)         | Generates a Table of Contents from the Neorg file.                          |

</details>

<!-- TODO: What to do with core.keybinds?  -->

### External Modules

Users can contribute and create their own modules for Neorg.
To use them, just download the plugin with your package manager, for instance with Packer:

```lua
use {
    "nvim-neorg/neorg",
    requires = "john-cena/cool-neorg-plugin",
}
```

After that it's as easy as loading the module it exposes normally:

```lua
require('neorg').setup {
    load = {
        ["cool.module"] = {},
    }
}
```

<details>
<summary>List of community modules:</summary>

| Module name                                                                        | Description                                                                          |
| :--------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------- |
| [`external.gtd-project-tags`](https://github.com/esquires/neorg-gtd-project-tags) | Provides a view of tasks grouped with a project tag. Requires `core.gtd.base`        |
| [`external.integrations.gtd-things`](https://github.com/danymat/neorg-gtd-things) | Use Things3 database to fetch and update tasks instead. Requires `core.gtd.base`        |
| [`core.integrations.telescope`](https://github.com/nvim-neorg/neorg-telescope)     | Neorg integration with [Telescope](https://github.com/nvim-telescope/telescope.nvim) |


</details>
<br>

**You're now basically set**! The rest of this README will be additional information, so keep reading
if you care about what makes Neorg tick.

## Philosophy
Our goals are fairly simple:

1. Revise the org format: simple, extensible, unambiguous. Will make you feel right at home. Alternate markup formats have several flaws, but the most
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
   If something has a more niche use case, it should be documented.

## Roadmap
We track a high-level roadmap, so that you can know what to expect. Just do `:h neorg-roadmap`.
To know exactly what's being worked on, just check out the [repo's PRs](https://github.com/nvim-neorg/neorg/pulls).

## FAQ

<!-- TODO(vhyrro): Populate with common issues -->

The wiki is the go-to place if you need answers to anything Neorg-related. Usage, Keybinds, User Callbacks, Modules, Events?
It's all there, so we recommend you seriously go [read it](https://github.com/nvim-neorg/neorg/wiki)!

## Contributing

Have an idea? An improvement to existing functionality? Feedback in general?

We seriously recommend you join our [discord](https://discord.gg/T6EgTAX7ht) to hang out and chat about your ideas,
plus that you read the [CONTRIBUTING.md](docs/CONTRIBUTING.md) file for more info about developer-related stuff!

## Credits

Massive shoutouts go to all the contributors actively working on the project together to form a fantastic
integrated workflow:

- [mrossinek](https://github.com/mrossinek) - for basically being my second brain when it comes to developing new features
                                              and adding new syntax elements
- [danymat](https://github.com/danymat) - for creating the excellent GTD workflow in Neorg that we literally use internally
                                          to plan new features

And an extra thank you to:
- [Binx](https://github.com/Binx-Codes/) - for making that gorgeous logo for free!
- [bandithedoge](https://github.com/bandithedoge) - for converting the PNG version of the logo into SVG form

## Support

Love what I do? Want to see more get done faster? Want to support future projects? Any sort of support is always
heartwarming and fuels the urge to keep going :heart:. You can show support here:

- [Buy me a coffee!](https://buymeacoffee.com/vhyrro)
- [Support me on LiberaPay](https://liberapay.com/vhyrro)
- [Donate directly via paypal](https://paypal.me/ewaczupryna?locale.x=en_GB)
- [Support me on Patreon](https://patreon.com/vhyrro)
- Donate to my monero wallet: `86CXbnPLa14F458FRQFe26PRfffZTZDbUeb4NzYiHDtzcyaoMnfq1TqVU1EiBFrbKqGshFomDzxWzYX2kMvezcNu9TaKd9t`
- Donate via bitcoin: `bc1q4ey43t9hhstzdqh8kqcllxwnqlx9lfxqqh439s`

<!-- TODO: Create table of donation links for all maintainers -->
