# General TODOS:
# - Extract into modules for better readability
# - Add comments explaining the more terse parts of the flake.
{
  description = "Flake for Neorg development and testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    gen-luarc.url = "github:mrcjkb/nix-gen-luarc-json";
    gen-luarc.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    gen-luarc,
    git-hooks,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      _module.args = {inherit gen-luarc git-hooks;};

      imports = [
        ./nix/overlays
        ./nix/checks
      ];

      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        lib,
        ...
      }: let
      in {
        formatter = pkgs.alejandra;

        packages.integration-test = let
          kickstart-config =
            pkgs.writeScript "kickstart.lua"
            ''
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

                    vim.cmd.e("success")

                    vim.wo.foldlevel = 99
                    vim.wo.conceallevel = 2
                  end,
                }
              })
            '';
        in
          pkgs.writeShellApplication {
            name = "neorg-integration-test";

            runtimeInputs = with pkgs; [neovim-unwrapped tree-sitter lua5_1 wget kickstart-config];

            text = ''
              export NVIM_APPNAME="nvim-neorg"

              echo "* Hello World!" > example.norg

              nvim --headless -u ${kickstart-config} example.norg -c wq

              rm example.norg

              if [ ! -f success ]; then
                  echo "Integration test failed!"
                  exit 1
              fi

              rm success
            '';
          };

        devShells.default = pkgs.mkShell {
          name = "neorg devShell";

          shellHook = ''
            ln -fs ${pkgs.luarc-to-json pkgs.luarc-with-dependencies} .luarc.json
          '';

          packages = with pkgs; [
            lua-language-server
            stylua
            lua51Packages.luacheck
            nil
            lua5_1
          ];
        };
      };
    };
}
