<!-- ttttt.txt g?? -->

<div align="center">

<img src="res/neorg.svg" width=315>

# Neorg - An Organized Future

<a href="https://github.com/neovim/neovim"> ![Requires](https://img.shields.io/badge/requires-neovim%200.5%2B-green?style=flat-square&logo=neovim) </a>
<a href="https://discord.gg/T6EgTAX7ht"> ![Discord](https://img.shields.io/badge/discord-join-7289da?style=flat-square&logo=discord) </a>
<a href="https://paypal.me/ewaczupryna?locale.x=en_GB"> ![Paypal](https://img.shields.io/badge/support-paypal-blue?style=flat-square&logo=paypal) </a>
<a href="https://www.buymeacoffee.com/vhyrro"> ![BuyMeACoffee](https://img.shields.io/badge/support-buy%20me%20a%20coffee-ffdd00?style=flat-square&logo=buy-me-a-coffee) </a>
<a href="https://patreon.com/vhyrro"> ![Patreon](https://img.shields.io/badge/support-patreon-F96854?style=flat-square&logo=patreon) </a>

<a href="/LICENSE"> ![License](https://img.shields.io/badge/license-GPL%20v3-brightgreen?style=flat-square) </a>
<a href="#wip"> ![Status](https://img.shields.io/badge/status-WIP-informational?style=flat-square) </a>

---

Life Organization Tool Written in Lua

[Introduction](#star2-introduction)
•
[Installation](#wrench-installation)
•
[Usage](#question-usage)
•
[Keybinds](#keyboard-keybinds)
•
[Wiki](#notebook-consult-the-wiki)

[GIFS](#camera-extra-gifs)

[Credits: Logo by Binx](#green_heart-credits)

</div>

---

> The pain... it won't stop. After so much oppression from other text editors, it's time we fight back.
With the introduction of lua, we *will* fight back.

<div align="center">

---

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

# :star2: Introduction
Neorg is a tool designed to reimagine organization as you know it. *Neo* - new, *org* - organization.
Grab some coffee, start writing some notes, let your editor handle the rest.

**Why do we need Neorg**? There are currently projects designed to [clone org-mode from emacs](https://github.com/kristijanhusak/orgmode.nvim),
what is the goal of this project? Whilst those projects are amazing, it's simply not enough. We need our _own, better_ solution - one that will
surpass _every_ other text editor. One that will give you all the bragging rights for using Neovim. Here's how we'll do it:
- Revise the org format - Simple, very extensible, unambiguous. Will make you feel right at home. Org and markdown have several flaws, but the most
  notable one is the requirement for **complex parsers**.
  I really advise educating yourself on just how bad markdown can get at times;
  what if we told you it's possible to eliminate those problems completely,
  all whilst keeping that familiar markdown feel?

  Enter the .norg file format, whose base spec is [almost complete](docs/NFF-0.1-spec.md).
  The cross between all the best things from org and the best things from markdown, revised and merged into one.
- Keybinds that _make sense_ - vim's keybind philosophy is unlike any other, and we want to keep that vibe.
  Keys form a "language", one that you can speak, not one that you need to learn off by heart.
- Infinite extensibility - no, that isn't a hyperbole. We mean it. Neorg is built upon an insanely modular and
  configurable backend - keep what you need, throw away what you don't care about. Use the defaults or change 'em.
  You are in control of what code runs and what code doesn't run.
- Logic. Everything has a reason, everything has logical meaning. If there's a feature, it's there because it's necessary, not because
  two people asked for it.

###### _IMPORTANT_: Neorg is *alpha* software. We consider it stable however be prepared for changes and potentially outdated documentation. We are advancing fast and keeping docs up-to-date would be very painful.

# :wrench: Installation
Installation may seem a bit daunting, however it's nothing you can't understand. If you really like to be in control,
you can read exactly what the below code snippets do in the [wiki](https://github.com/nvim-neorg/neorg/wiki/Installation).
You can install through any plugin manager (it can even be vimscript plugin managers, as long as you're running Neovim version 0.5 or higher).

> :exclamation: NOTE: Neorg requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) to operate, so be sure to install it alongside Neorg!

- [Packer](https://github.com/wbthomason/packer.nvim):
  ```lua
  use { 
      "nvim-neorg/neorg",
      config = function()
          require('neorg').setup {
              -- Tell Neorg what modules to load
              load = {
                  ["core.defaults"] = {}, -- Load all the default modules
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

  You can put the configuration directly in packer's `config` table (as shown above) or in a separate location within your config
  (make sure the configuration code runs after Neorg is loaded!):
  ```lua
  require('neorg').setup {
      -- Tell Neorg what modules to load
      load = {
          ["core.defaults"] = {}, -- Load all the default modules
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
  ```

  Want to lazy load? Turns out that can be rather problematic. You can use the `ft` key to load Neorg only upon entering a .norg file.
  Here's an example:

  ```lua
  use {
    "nvim-neorg/neorg",
    -- in case you turn off filetype detection when startup neovim, or ft detection failure for norg
    setup = vim.cmd("autocmd BufRead,BufNewFile *.norg setlocal filetype=norg"),
    after = {"nvim-treesitter"},  -- you may also specify telescope
    ft = "norg",
    config = function()
      -- setup neorg
      require('neorg').setup {
        ...
      }

    end
  }
  ```

  However, don't expect everything to work. You might need additional setups depending on how your lazyloading system is configured.
  Neorg practically lazy loads itself - only a few lines of code are run on startup, these lines check whether the current
  extension is `.norg`, if it's not then nothing else loads. You shouldn't have to worry about performance issues.

  After all of that resource the current file and `:PackerSync`:

  ![PackerSync GIF](https://user-images.githubusercontent.com/13149513/125273068-5c365f00-e32e-11eb-95a4-b8c2c0d3b85e.gif)

 - [vim-plug](https://github.com/junegunn/vim-plug):
   ```vim
   Plug 'nvim-neorg/neorg' | Plug 'nvim-lua/plenary.nvim'
   ```
   
   Afterwards resource the current file and to install plugins run `:PlugInstall`.

   You can put this initial configuration in your init.vim file:
   ```vim
   lua << EOF
       require('neorg').setup {
           -- Tell Neorg what modules to load
           load = {
               ["core.defaults"] = {}, -- Load all the default modules
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
   EOF
   ```

##### :robot: For the latest and greatest check out the [unstable](https://github.com/nvim-neorg/neorg/tree/unstable) branch

### Setting up TreeSitter
As of right now, the TreeSitter parser is in its early stage. To install it, you want to run this code snippet before you invoke
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
```
Then run `:TSInstall norg`.
If you want the parser to be more persistent across different installations of your config make sure to set `norg` as a parser in the `ensure_installed` table, then run `:TSUpdate`.
Here's an example config, yours will probably be different:
```lua
require('nvim-treesitter.configs').setup {
	ensure_installed = { "norg", "haskell", "cpp", "c", "javascript", "markdown" },
}
```

Having a rare occurence where the parser doesn't work instantly? Try running `:e`.
You'll only need to run it once in your lifetime, for some reason TS doesn't have issues after that.

**Still not working**? Uh oh, you're stepping on muddy territory. There are several reasons why a parser
may not work right off the bat, however most commonly it's because of plugin loading order. Neorg needs
`nvim-treesitter` to be up and running before it starts adding colours to highlight groups.
With packer this can be achieved with an `after = "nvim-treesitter"` flag in your `use` call to Neorg.
Not using packer? Make sure that Neorg's `setup()` gets called after `nvim-treesitter`'s setup. If nothing else works
then try creating an `after/ftplugin/norg.lua` file and paste your Neorg configuration there.

It's a bit hacky - it will unfortunately stay this way until we get first-class support in the `nvim-treesitter` repository.
Sorry!

### Setting up a Completion Engine
Neorg comes with its own API for completion. Users can then write integration modules to allow different plugins like `nvim-compe` and `nvim-cmp`
to communicate with the Neorg core. By default no engine is specified. To specify one, make sure to configure `core.norg.completion`:

```lua
["core.norg.completion"] = {
	config = {
		engine = "nvim-compe" | "nvim-cmp" -- We current support nvim-compe and nvim-cmp only
	}
}
```

#### Compe
Make sure to set `neorg` to `true` in the `source` table for nvim-compe:
```lua
source = {
    path = true,
    buffer = true,
    <etc.>,
    neorg = true
}
```

#### Cmp
Make sure to enable the `neorg` completion source in the cmp sources table:
```lua
sources = {
	...
	{ name = "neorg" }
}
```

And that's it!

# :question: Usage
Simply drop into a .norg file and start typing!

![Usage Showcase](https://user-images.githubusercontent.com/13149513/125274594-ef23c900-e32f-11eb-83dd-88627a038e01.gif)

You may realize that we don't have an insane amount of frontend features just yet.
This doesn't mean the plugin isn't capable of those things, it just means we're working on them!
We tried focusing heavily on the backend first, but now that that is almost done we are actually starting work on features just for you:
- [x] Telescope.nvim integration for several things (see https://github.com/nvim-neorg/neorg-telescope)
- [x] TreeSitter parser (can be found [here](https://github.com/nvim-neorg/tree-sitter-norg))
	- [x] AST Generation
	- [x] Custom highlight support
	- [x] Custom folds
	- [x] Language injection (for code blocks)
	- [ ] Smarter todo item toggling with the TreeSitter AST

It's all about the patience! We're gonna deliver all the juicy features ASAP.
In the meantime you might be interested in reading the [spec](docs/NFF-0.1-spec.md) and familiarizing yourself with the new format :D

Here are some things we *are* working on:
- Fully fledged GTD workflow (with @Danymat)
- Dynamically displaying and interacting with a Table of Contents (with @mrossinek)
- Better parsing of markup (bold, italic etc.)
- Overhauled indentation engine

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
Get syntax highlighting for any language that's supported by treesitter.

![Injection](https://user-images.githubusercontent.com/13149513/125274035-5f7e1a80-e32f-11eb-8de3-060b6e752185.gif)

### Smort Syntax
Thanks to TreeSitter we can achieve a surprising amount of precision.

![Trailing Modifier Showcas](https://user-images.githubusercontent.com/13149513/125274133-79b7f880-e32f-11eb-86c3-c06f1484b685.gif)
![Comments](https://user-images.githubusercontent.com/13149513/125274156-80467000-e32f-11eb-935c-a65460b3fc61.gif)

### Completion
Neorg uses both TreeSitter and nvim-compe in unison to provide
contextual completion based on your position in the syntax tree.

![Completion](https://user-images.githubusercontent.com/13149513/125274303-a835d380-e32f-11eb-9a75-a2a4eb421a61.gif)
![Code Tag Completion](https://user-images.githubusercontent.com/13149513/125274336-aff57800-e32f-11eb-88e0-dfd9895d5d26.gif)


# :purple_heart: Support
Love what I do? Want to see more get done faster? Want to support future projects of mine? Any sort of support is always
heartwarming and fuels the urge to keep going :heart:. You can support me here:
- [Buy me a coffee!](https://buymeacoffee.com/vhyrro)
- [Support on LiberaPay](https://liberapay.com/vhyrro)
- [Donate directly via paypal](https://paypal.me/ewaczupryna?locale.x=en_GB)
- [Support me on Patreon](https://patreon.com/vhyrro)

# :green_heart: Credits
Massive shoutouts to the people who supported the project! These are:
- Binx, for making that gorgeous logo for free!
	- [Github](https://github.com/Binx-Codes/)
	- [Reddit](https://www.reddit.com/u/binxatmachine)
- bandithedoge, for recreating the logo in svg form!
	- [Website](https://bandithedoge.com)
	- [Github](https://github.com/bandithedoge)
	- [YouTube](https://youtube.com/bandithedoge)
