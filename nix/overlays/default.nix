{
  self,
  inputs,
  gen-luarc,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;

      overlays = [
        gen-luarc.overlays.default

        (final: prev: {
          lib = prev.lib // import ./lib.nix {inherit pkgs;};

          # NOTE: I would have used callPackage for easy overriding, but
          # this changes the type and *-to-json fails later. To be figured out.
          luarc-with-dependencies = final.lib.callPackageNoOverridable ./luarc.nix {inherit self;};
        })
      ];
    };
  };
}
