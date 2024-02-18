<div align="center">

<img src="res/neorg.svg" width=300>

# Neorg - An Organized Future

<a href="https://neovim.io"> ![Neovim](https://img.shields.io/badge/Neovim%200.8+-brightgreen?style=for-the-badge) </a>
<a href="https://discord.gg/T6EgTAX7ht"> ![Discord](https://img.shields.io/badge/discord-join-7289da?style=for-the-badge&logo=discord) </a>
<a href="/LICENSE"> ![License](https://img.shields.io/badge/license-GPL%20v3-brightgreen?style=for-the-badge)</a>
<a href="https://dotfyle.com/plugins/nvim-neorg/neorg"> ![Usage](https://dotfyle.com/plugins/nvim-neorg/neorg/shield?style=for-the-badge) </a>

Your New Life Organization Tool - All in Lua

[Summary](#summary)
•
[Tutorial](#-tutorial)
•
[Installation](#-installationquickstart)
•
[Setup](#-setup)
•
[Usage](#-usage)
<br>
[Modules](#-modules)
•
[Roadmap](/ROADMAP.md)
•
[Philosophy](#-philosophy)
•
[FAQ](#-faq)

</div>

<div align="center">

<br>

## Summary

</div>

Neorg (_Neo_ - new, _org_ - organization) is a Neovim plugin designed to reimagine organization as you know it.
Grab some coffee, start writing some notes, let your editor handle the rest.

### What is Neorg?

Neorg is an all-encompassing tool based around structured note taking, project and task management, time
tracking, slideshows, writing typeset documents and much more. The premise is that all of these features are
built on top of a single base file format (`.norg`), which the user only has to learn once to gain access to
all of Neorg's functionality.

Not only does this yield a low barrier for entry for new users it also ensures that all features are integrated with each
other and speak the same underlying language. The file format is built to be expressive and easy to parse,
which also makes `.norg` files easily usable anywhere outside of Neorg itself.

To learn more about the philosophy of the project check the [philosophy](#-philosophy) section.

###### :exclamation: **IMPORTANT**: Neorg is young software. We consider it stable however be prepared for occasional breaking workflow changes. Make sure to pin the version of Neorg you'd like to use and only update when you are ready.

## 🌟 Tutorial

<div>

<a href="https://www.youtube.com/watch?v=NnmRVY22Lq8&list=PLx2ksyallYzVI8CN1JMXhEf62j2AijeDa&index=1">
 <img src="https://img.youtube.com/vi/NnmRVY22Lq8/0.jpg" style="width:75%;">
</a>

</div>

## 🔧 Installation/Quickstart

**Neorg requires at least Neovim 0.8+ to operate.**

### TL;DR

For neovim beginners who don't want to tinker with the configurations:

1. Install one of the Nerd fonts, for example Meslo Nerd Font from  [Nerd Fonts](https://www.nerdfonts.com/font-downloads).
2. Set your terminal font to the monospace variant of the installed font, for example "MesloLGM Nerd Font Mono".
3. Make sure you have git by running `git --version`
4. Paste the sample init.lua below to `~/.config/nvim/init.lua`
5. Start taking notes by `nvim test.norg`


  <details>
  <summary>sample init.lua</summary>

  ```lua
  -- adapted from https://github.com/folke/lazy.nvim#-installation

  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.loop.fs_stat(lazypath) then
    print(vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      lazypath,
    }))
  end
  vim.opt.rtp:prepend(lazypath)
  
  vim.g.mapleader = " "
  
  require("lazy").setup({
    "rebelot/kanagawa.nvim",  -- neorg needs a colorscheme with treesitter support
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      opts = {
        highlight = { enable = true },
      },
      config = function(_, opts)
        require("nvim-treesitter.configs").setup(opts)
      end,
    },
    {
      "nvim-neorg/neorg",
      build = ":Neorg sync-parsers",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("neorg").setup {
          load = {
            ["core.defaults"] = {},
            ["core.concealer"] = {},
            ["core.dirman"] = {
              config = {
                workspaces = {
                  notes = "~/notes",
                },
                default_workspace = "notes",
              },
            },
          },
        }
  
        vim.wo.foldlevel = 99
        vim.wo.conceallevel = 2
      end,
    }
  })
  
  vim.cmd.colorscheme('kanagawa')
  ```

  </details>

### Installation

You can install it through your favorite plugin manager:

-
  <details>
  <summary><a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a></summary>

  ```lua
  use {
      "nvim-neorg/neorg",
      config = function()
          require('neorg').setup {
              load = {
                  ["core.defaults"] = {}, -- Loads default behaviour
                  ["core.concealer"] = {}, -- Adds pretty icons to your documents
                  ["core.dirman"] = { -- Manages Neorg workspaces
                      config = {
                          workspaces = {
                              notes = "~/notes",
                          },
                      },
                  },
              },
          }
      end,
      run = ":Neorg sync-parsers",
      requires = "nvim-lua/plenary.nvim",
  }
  ```

  Every time Neorg hits a new release, a new tag is created by us, so you don't have to worry about all the updates inbetween.
  That means that adding `tag = "*"` in Packer will update to latest stable release.

  You can also pin Neorg to one specific version through e.g. `tag = "2.0.0"`.

  ---

  Want to lazy load? You can use the `ft` key to load Neorg only upon entering a `.norg` file:

  ```lua
  use {
      "nvim-neorg/neorg",
      -- tag = "*",
      ft = "norg",
      after = "nvim-treesitter", -- You may want to specify Telescope here as well
      config = function()
          require('neorg').setup {
              load = {
                  ["core.defaults"] = {}, -- Loads default behaviour
                  ["core.concealer"] = {}, -- Adds pretty icons to your documents
                  ["core.dirman"] = { -- Manages Neorg workspaces
                      config = {
                          workspaces = {
                              notes = "~/notes",
                          },
                      },
                  },
              },
          }
      end
  }
  ```

  Although it's proven to work for a lot of people, you might need to take some
  additional steps depending on how your lazyloading system and/or Neovim
  config is set up.

  </details>

- <details>
  <summary><a href="https://github.com/junegunn/vim-plug">vim-plug</a></summary>

  ```vim
  Plug 'nvim-neorg/neorg' | Plug 'nvim-lua/plenary.nvim'
  ```

  You can then put this initial configuration in your `init.vim` file:

  ```vim
  lua << EOF
  require('neorg').setup {
      load = {
          ["core.defaults"] = {}, -- Loads default behaviour
          ["core.concealer"] = {}, -- Adds pretty icons to your documents
          ["core.dirman"] = { -- Manages Neorg workspaces
              config = {
                  workspaces = {
                      notes = "~/notes",
                  },
              },
          },
      },
  }
  EOF
  ```

  </details>
- <details>
  <summary><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

  ```lua
  require("lazy").setup({
    {
      "nvim-neorg/neorg",
      build = ":Neorg sync-parsers",
      lazy = false, -- specify lazy = false because some lazy.nvim distributions set lazy = true by default
      -- tag = "*",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("neorg").setup {
          load = {
            ["core.defaults"] = {}, -- Loads default behaviour
            ["core.concealer"] = {}, -- Adds pretty icons to your documents
            ["core.dirman"] = { -- Manages Neorg workspaces
              config = {
                workspaces = {
                  notes = "~/notes",
                },
              },
            },
          },
        }
      end,
    },
  })
  ```

  If you want to lazy load the plugin and split it into a separate file, here is the snippet. (be careful, you'll not get command completion the first time)
  ```lua
  return {
    "nvim-neorg/neorg",
    dependencies = { "nvim-lua/plenary.nvim" },
    build = ":Neorg sync-parsers",
    -- tag = "*",
    lazy = true, -- enable lazy load
    ft = "norg", -- lazy load on file type
    cmd = "Neorg", -- lazy load on command
    config = function()
      require("neorg").setup {
        load = {
          ["core.defaults"] = {}, -- Loads default behaviour
          ["core.concealer"] = {}, -- Adds pretty icons to your documents
          ["core.dirman"] = { -- Manages Neorg workspaces
            config = {
              workspaces = {
                notes = "~/notes",
              },
            },
          },
        },
      }
    end,
  }
  ```

  </details>

### Treesitter

###### _Be sure to have [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) installed on your system for this step!_
Neorg will automatically attempt to install the parsers for you upon entering a `.norg` file if you have `core.defaults` loaded.
A command is also exposed to reinstall and/or update these parsers: `:Neorg sync-parsers`.

It is important to note that installation via this command isn't reproducible.
There are a few ways to make it reproducible, but the recommended way is to set up an **update flag** for your plugin
manager of choice. In packer, your configuration may look something like this:
```lua
use {
    "nvim-neorg/neorg",
    run = ":Neorg sync-parsers", -- This is the important bit!
    config = function()
        require("neorg").setup {
            -- configuration here
        }
    end,
}
```

With the above `run` key set, every time you update Neorg the internal parsers
will also be updated to the correct revision.

## 📦 Setup

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

You can see [here](https://github.com/nvim-neorg/neorg/wiki#default-modules) which modules are automatically required when loading `core.defaults`.

## ⚙ Usage

A new and official specification is in the works, we recommend reading it [here](https://github.com/nvim-neorg/norg-specs/blob/main/1.0-specification.norg).
You can view a summary directly in your neovim instance by running `:h neorg` if you don't like reading a lot!

Afterwards it's as simple as hopping into a `.norg` file and typing away.

A good first step is to require the `core.dirman` module, it'll help you manage Neorg workspaces.
Workspaces are basically isolated directories that you can jump between:

```lua
require('neorg').setup {
    load = {
        ["core.defaults"] = {},
        ["core.dirman"] = {
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
Voila!

#### It works, cool! What are the next steps?

We recommend you add some core modules that can greatly improve your experience, such as:

- Using the concealer module to enable icons (`core.concealer`)
- Setting up a completion engine (`core.completion`)

Setting these up is discussed in the wiki, so be sure to check there!

**You're now basically set**! The rest of this README will be additional information, so keep reading
if you care about what makes Neorg tick, or you want to genuinely get good at using it.

## 🥡 Modules

As you saw previously, we loaded `core.defaults` and recommended that you load `core.dirman`.
As you probably know those are modules. But what are they, exactly?

Modules are basically isolated bits of code that provide a specific subset of features. They can be docked into
the environment at any time and can be essentially stacked together like lego bricks!
They can bind themselves to events and callbacks and communicate with each other.

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

As always, for a little more info you can consult the wiki page [here](https://github.com/nvim-neorg/neorg/wiki/#module-naming-convention).
To know which configurations are provided by default for a module, just click on their link: you'll go to the module page in the [wiki](https://github.com/nvim-neorg/neorg/wiki).

### Core Modules

[Here](https://github.com/nvim-neorg/neorg/wiki#default-modules) is a list of core modules that aren't part of `core.defaults` and can be added
individually by you.

Feel free to try by adding them to your Neorg setup.

### External Modules

Users can contribute and create their own modules for Neorg.
To use them, just download the plugin with your package manager, for instance with Packer:

```lua
use {
    "nvim-neorg/neorg",
    requires = "john-cena/cool-neorg-plugin",
}
```

After that it's as easy as loading the exposed module normally:

```lua
require('neorg').setup {
    load = {
        ["cool.module"] = {},
    }
}
```

A comprehesive list of community made modules can be found [in the awesome-neorg repo](https://github.com/NTBBloodbath/awesome-neorg)!

## ❓ Philosophy

Our goals are fairly simple:

1. Revise the org format: simple, extensible, unambiguous. Will make you feel right at home. Alternate markup formats have several flaws, but the most
   notable one is the requirement for **complex and slow parsers**.
   What if we told you it's possible to alleviate those problems, all whilst keeping that familiar feel?
   Enter the `.norg` file format, whose specification can be found [here](https://github.com/nvim-neorg/norg-specs/blob/main/1.0-specification.norg).
   The cross between all the best things from org and the best things from markdown, revised and merged into one.

2. Keybinds that _make sense_: vim's keybind philosophy is unlike any other, and we want to keep that vibe.
   Keys form a "language", one that you can speak, not one that you need to learn off by heart.

3. Infinite extensibility: no, that isn't a hyperbole. We mean it. Neorg is built upon an insanely modular and
   configurable backend - keep what you need, throw away what you don't care about. Use the defaults or change 'em.
   You are in control of what code runs and what code doesn't run!

4. Logic: everything has a reason, everything has logical meaning. If there's a feature, it's there because it's necessary, not because
   two people asked for it.
   If something has a more niche use case, it should be documented.

## 📚 FAQ

The wiki is the go-to place if you need answers to anything Neorg-related. Usage, Keybinds, User Callbacks, Modules, Events?
It's all there, so we recommend you seriously go [read it](https://github.com/nvim-neorg/neorg/wiki)!

## Troubleshooting

If you feel that you're in trouble or some component like Treesitter is not working check the
[Dependencies.md](https://github.com/nvim-neorg/neorg/wiki/Dependencies) file for many common issues
unrelated to the Neorg core.

## Contributing

Have an idea? An improvement to existing functionality? Feedback in general?

We seriously recommend you join our [discord](https://discord.gg/T6EgTAX7ht) to hang out and chat about your ideas,
plus that you read the [CONTRIBUTING.md](docs/CONTRIBUTING.md) file for more info about developer-related stuff!

## Credits

Massive shoutouts go to all the contributors actively working on the project together to form a fantastic
integrated workflow:

- [mrossinek](https://github.com/mrossinek) - for basically being my second brain when it comes to developing new features
  and adding new syntax elements
- [danymat](https://github.com/danymat) - for creating the excellent foundations for the up and coming GTD system

And an extra thank you to:

- [Binx](https://github.com/dvchoudh) - for making that gorgeous logo for free!
- [bandithedoge](https://github.com/bandithedoge) - for converting the PNG version of the logo into SVG form

## Support

Love what I do? Want to see more get done faster? Want to support future projects? Any sort of support is always
heartwarming and fuels the urge to keep going :heart:. You can show support here:

- [Buy me a coffee!](https://buymeacoffee.com/vhyrro)
- [Support me via Github Sponsors](https://github.com/sponsors/vhyrro)
- [Support me on Patreon](https://patreon.com/vhyrro)

Immense thank you to all of the sponsors of my work!

<div align="center">

<!-- sponsors --><a href="https://github.com/vsedov"><img src="https://github.com/vsedov.png" width="60px" alt="vsedov" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/bR3iN"><img src="https://github.com/bR3iN.png" width="60px" alt="bR3iN" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/skbolton"><img src="https://github.com/skbolton.png" width="60px" alt="skbolton" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/molleweide"><img src="https://github.com/molleweide.png" width="60px" alt="molleweide" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/theherk"><img src="https://github.com/theherk.png" width="60px" alt="theherk" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/purepani"><img src="https://github.com/purepani.png" width="60px" alt="purepani" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/refaelsh"><img src="https://github.com/refaelsh.png" width="60px" alt="refaelsh" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/tromars"><img src="https://github.com/tromars.png" width="60px" alt="tromars" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/rbereziuk"><img src="https://github.com/rbereziuk.png" width="60px" alt="rbereziuk" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/zettlrobert"><img src="https://github.com/zettlrobert.png" width="60px" alt="zettlrobert" /></a>&nbsp;&nbsp;&nbsp;<!-- sponsors -->

</div>
