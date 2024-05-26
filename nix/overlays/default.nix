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

        (_: prev: {
          # NOTE: I would have use callPackage for easy overriding, but
          # this changes the type and *-to-json fails later. To figure out.
          luarc-with-dependencies = import ./luarc.nix {
            inherit self;
            inherit (pkgs) lib mk-luarc runCommand lua51Packages wget;
          };
        })
      ];
    };
  };
}
