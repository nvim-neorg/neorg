<div align="center">

# Instantaneous Neorg Setup

Get up and running with Neorg even with zero Neovim knowledge.

</div>

## Prerequisites

To use this configuration, a set of prerequisites must be fulfilled beforehand.

1. Install one of the Nerd fonts, for example Meslo Nerd Font from [Nerd Fonts](https://www.nerdfonts.com/font-downloads).
2. Set your terminal font to the installed Nerd Font.
3. Make sure you have git by running `git --version`.
4. Ensure you have Lua 5.1 *or* LuaJIT installed on your system:
   - **Windows**: install [lua for windows](https://github.com/rjpcomputing/luaforwindows/releases/tag/v5.1.5-52).
   - **MacOS**: install via `brew install luajit`. Lua 5.1 is incorrectly marked as "deprecated" on MacOS systems, therefore luajit should be used instead.
   - **`apk`**: `sudo apk add luajit luajit-dev wget`
   - **`apt`**: `sudo apt install liblua5.1-0-dev`
   - **`dnf`**: `sudo dnf install compat-lua-devel-5.1.5`
   - **`pacman`**: `sudo pacman -Syu luajit`

## Troubleshooting

If you have any issues like bold or italic not rendering or highlights being improperly applied
I encourage you to check out the [dependencies document](https://github.com/nvim-neorg/neorg/wiki/Dependencies) which explains troubleshooting steps
for different kinds of terminals.

With that, let's begin!

## Creating our Init File
 
- Open up a Neovim instance and run the following command: `:echo stdpath("config")`.
  This will return the path where Neovim expects your `init.lua` to exist.
- Navigate to that directory (create it if it doesn't exist) and create a file
  called `init.lua` there. On Linux this will likely be `~/.config/nvim/init.lua`.

  Put the following into the `init.lua` file:
  ```lua
  -- Adapted from https://github.com/folke/lazy.nvim#-installation
  
  -- Install lazy.nvim
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable", -- latest stable release
      lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
  
  -- Set up both the traditional leader (for keymaps) as well as the local leader (for norg files)
  vim.g.mapleader = " "
  vim.g.maplocalleader = ","
  
  require("lazy").setup({
    {
      "rebelot/kanagawa.nvim", -- neorg needs a colorscheme with treesitter support
      config = function()
          vim.cmd.colorscheme("kanagawa")
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      opts = {
        ensure_installed = { "c", "lua", "vim", "vimdoc", "query" },
        highlight = { enable = true },
      },
      config = function(_, opts)
        require("nvim-treesitter.configs").setup(opts)
      end,
    },
    {
        "vhyrro/luarocks.nvim",
        priority = 1000,
        config = true,
    },
    {
      "nvim-neorg/neorg",
      dependencies = { "luarocks.nvim" },
      version = "*",
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
  ```
- Close and reopen Neovim. Everything should just work! If you do not see Neorg working
  for any reason, run `:Lazy build luarocks.nvim` and afterwards `:Lazy build neorg`.
- Open up any `.norg` file and start typing!
