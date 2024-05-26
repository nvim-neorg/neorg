{pkgs, ...}: {
  devShells.default = pkgs.callPackage ./neorg-shell.nix {};
}
