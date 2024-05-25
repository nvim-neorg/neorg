# General TODOS:
# - Extract into modules for better readability
# - Readd integration tests
# - Add comments explaining the more terse parts of the flake.
{
  description = "Flake for Neorg development and testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    gen-luarc.url = "github:mrcjkb/nix-gen-luarc-json";
    gen-luarc.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
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
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        lib,
        ...
      }: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            gen-luarc.overlays.default
          ];
        };
        dependencies = builtins.fromJSON (builtins.readFile ./res/deps.json);
        install-dependencies =
          pkgs.runCommand "install-neorg-dependencies" {
            nativeBuildInputs = with pkgs; [lua51Packages.luarocks wget];
            outputHashAlgo = "sha256";
            outputHashMode = "recursive";
            outputHash = "sha256-SOsIgtmkXTKMZrKUHHzAf+XAshl/J7+DN9RFeLz+DDY=";
          } ''
            mkdir $PWD/home
            export HOME=$PWD/home
            mkdir -p $out/luarocks

            ${lib.concatStrings (lib.mapAttrsToList (name: version: ''luarocks install --tree="$out/luarocks" --force-lock --local ${name} ${version}'' + "\n") dependencies)}
          '';
        luarc = pkgs.mk-luarc {};
        luarc-with-dependencies =
          luarc
          // {
            inherit (luarc) runtime;
            inherit (luarc.Lua) diagnostics globals;
            Lua.workspace = {
              inherit (luarc.Lua.workspace) ignoreDir;
              library = luarc.Lua.workspace.library ++ ["${install-dependencies}/luarocks/share/lua/5.1/"];
            };
          };
      in {
        formatter = pkgs.alejandra;

        checks.type-check = git-hooks.lib.${system}.run {
          src = ./lua;
          hooks = {
            lua-ls = {
              enable = true;
              settings.configuration = luarc-with-dependencies;
            };
          };
        };

        checks.pre-commit-check = git-hooks.lib.${system}.run {
          src = self;
          hooks = {
            alejandra.enable = true;
            luacheck.enable = true;
            # stylua.enable = true;
          };
        };

        devShells.default = pkgs.mkShell {
          name = "neorg devShell";

          shellHook = ''
            ln -fs ${pkgs.luarc-to-json luarc-with-dependencies} .luarc.json
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
