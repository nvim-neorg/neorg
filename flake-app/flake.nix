{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";

    neorg = {
      url = "github:nvim-neorg/neorg/v9.4.0";
      flake = false;
    };

    lua-utils = {
      url = "github:nvim-neorg/lua-utils.nvim/v1.0.2";
      flake = false;
    };

    nvim-treesitter = {
      url = "github:nvim-treesitter/nvim-treesitter/v0.9.3";
      flake = false;
    };

    pathlib = {
      url = "github:pysan3/pathlib.nvim/v2.2.3";
      flake = false;
    };

    nvim-nio = {
      url = "github:nvim-neotest/nvim-nio/v1.10.1";
      flake = false;
    };

    nui = {
      url = "github:MunifTanjim/nui.nvim/0.3.0";
      flake = false;
    };

    plenary = {
      url = "github:nvim-lua/plenary.nvim/v0.1.4";
      flake = false;
    };

    kanagawa = {
      url = "github:rebelot/kanagawa.nvim/aef7f5cec0a40dbe7f3304214850c472e2264b10";
      flake = false;
    };

    tree-sitter-norg = {
      url = "github:nvim-neorg/tree-sitter-norg/v0.2.6";
      flake = false;
    };

    tree-sitter-norg-meta = {
      url = "github:nvim-neorg/tree-sitter-norg-meta/v0.1.0";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      # Per-system attributes (packages, devShells)
      perSystem = { config, self', inputs', pkgs, system, ... }: let
        tsNorg = pkgs.stdenv.mkDerivation {
          name = "tree-sitter-norg";
          src = inputs.tree-sitter-norg;
          buildPhase = ''
            ${pkgs.gcc}/bin/gcc -c -fPIC -O2 -I src src/parser.c -o parser.o
            ${pkgs.gcc}/bin/g++ -c -fPIC -O2 -I src src/scanner.cc -std=c++14 -o scanner.o
            ${pkgs.gcc}/bin/g++ -shared -o parser.so parser.o scanner.o
          '';
          installPhase = ''
            mkdir -p $out/parser
            cp parser.so $out/parser/norg.so
          '';
        };
        tsNorgMeta = pkgs.stdenv.mkDerivation {
          name = "tree-sitter-norg-meta";
          src = inputs.tree-sitter-norg-meta;
          buildPhase = ''
            ${pkgs.gcc}/bin/gcc -shared -fPIC -O2 -I src -o parser.so src/parser.c
          '';
          installPhase = ''
            mkdir -p $out/parser
            cp parser.so $out/parser/norg_meta.so
          '';
        };
        parsers = pkgs.symlinkJoin {
          name = "ts-parsers";
          paths = [ tsNorg tsNorgMeta ];
        };

        nerdFonts = pkgs.nerd-fonts.meslo-lg;
        fontConf = pkgs.makeFontsConf { fontDirectories = [ nerdFonts ]; };

        mainNotesPath = "~/neorg-notes";
        nvimInitLua = ''
          vim.opt.runtimepath:append('${inputs.nvim-nio}')
          vim.opt.runtimepath:append('${inputs.lua-utils}')
          vim.opt.runtimepath:append('${inputs.plenary}')
          vim.opt.runtimepath:append('${inputs.nui}')
          vim.opt.runtimepath:append('${inputs.pathlib}')
          vim.opt.runtimepath:append('${inputs.nvim-treesitter}')
          vim.opt.runtimepath:append('${inputs.neorg}')
          vim.opt.runtimepath:append('${inputs.kanagawa}')
          vim.opt.runtimepath:append('${parsers}')

          require("nvim-treesitter.configs").setup {
            highlight = { enable = true },
          }

          require('neorg').setup {
            load = {
              ["core.defaults"] = {},
              ["core.integrations.treesitter"] = {
                config = {
                  configure_parsers = true,
                  install_parsers = false,  -- Since we provide them manually
                },
              },

              ["core.concealer"] = {},
              ["core.dirman"] = {
                config = {
                  workspaces = {
                    notes = "${mainNotesPath}",
                  },
                  default_workspace = "notes",
                },
              },
            },
          }

          vim.wo.foldlevel = 99
          vim.wo.conceallevel = 2
          vim.cmd.colorscheme "kanagawa"
        '';
        nvimInitLuaFile = pkgs.writeText "init.lua" nvimInitLua;
      in {
        packages.default = pkgs.writeShellScriptBin "neorg" ''
          export FONTCONFIG_FILE=${fontConf}
        
          args=(
            "${pkgs.xterm}/bin/xterm"
            -bg black -fg white  # force dark theme
            -xrm 'XTerm.omitTranslation: fullscreen'  # unbind alt+return keybind from xterm
            -fa 'MesloLGL Nerd Font Mono:style=Regular:size=12'  # config nerd font
            -fs 12  # font size
            -e "${pkgs.neovim}/bin/nvim"
            -u "${nvimInitLuaFile}"
            -c 'Neorg index'  # start neorg index upfront
          )
        
          exec "''${args[@]}"
        '';
      };
    };
}
