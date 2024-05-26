{
  self,
  git-hooks,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks = let
      callPackage = pkgs.lib.callPackageWith (pkgs // {inherit self git-hooks;});
    in {
      type-check = callPackage ./type-check.nix {};
      pre-commit-check = callPackage ./pre-commit-check.nix {};
    };
  };
}
