{pkgs}: rec {
  callPackageNoOverridableWith = originalAttrs: fun: additionalAttrs: let
    f =
      if pkgs.lib.isFunction fun
      then fun
      else import fun;
    attrs = builtins.intersectAttrs (pkgs.lib.functionArgs f) originalAttrs;
  in
    f (attrs // additionalAttrs);

  callPackageNoOverridable = callPackageNoOverridableWith pkgs;
}
