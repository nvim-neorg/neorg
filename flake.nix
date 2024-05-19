{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    gen-luarc.url = "github:mrcjkb/nix-gen-luarc-json";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = {
    self,
    nixpkgs,
    devenv,
    systems,
    gen-luarc,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    packages = forEachSystem (system: {
      devenv-up = self.devShells.${system}.default.config.procfileScript;
    });

    formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.alejandra);

    devShells =
      forEachSystem
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                gen-luarc.overlays.default
              ];
            };
            neorg-dependencies = builtins.fromJSON (builtins.readFile ./res/deps.json);
            luarc = pkgs.mk-luarc {
              plugins = builtins.attrNames neorg-dependencies;
            };
          in [
            {
              name = "neorg";

              languages.lua = {
                enable = true;
                package = pkgs.luajit;
              };

              pre-commit.hooks = {
                stylua.enable = true;
                luacheck.enable = true;
              };

              packages = [pkgs.luajitPackages.luarocks];

              enterShell =
                lib.attrsets.foldlAttrs (acc: name: version: "luarocks install --local ${name} ${version}" + "\n" + acc) "" neorg-dependencies
                + ''
                  ln -fs ${pkgs.luarc-to-json luarc} .luarc.json
                '';
            }
          ];
        };
      });
  };
}
