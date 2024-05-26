{pkgs, ...}: {
  packages.integration-test = pkgs.callPackage ./integration-test.nix {};
}
