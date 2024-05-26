# General TODOS:
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

      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;

        imports = [
          ./nix/packages
          ./nix/shells
        ];
      };
    };
}
