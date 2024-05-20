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
    dir = ".",
    name = "neorg",
    dependencies = { "luarocks.nvim" },
    config = function()
      vim.cmd.Lazy("build neorg")

      package.loaded.neorg = nil

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

      vim.cmd.e('success')
    end,
  }
})
