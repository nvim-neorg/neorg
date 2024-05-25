{
  lib,
  runCommand,
  lua51Packages,
  wget,
  self,
}: let
  # Temporarily remove the parsers due to installation problems on Nix. Causes the integration test to fail for now.
  dependencies = builtins.removeAttrs (builtins.fromJSON (builtins.readFile "${self}/res/deps.json")) ["tree-sitter-norg" "tree-sitter-norg-meta"];
in
  runCommand "install-neorg-dependencies" {
    nativeBuildInputs = [lua51Packages.luarocks wget];
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-tvMqTgTshVApj3muQyvwj+as/8b7tw1r0BlCTpMlGuU=";
  } ''
    mkdir $PWD/home
    export HOME=$PWD/home
    mkdir -p $out/luarocks

    ${lib.concatStrings (lib.mapAttrsToList (name: version:
      ''
        luarocks install --tree="$out/luarocks" --force-lock --local ${name} ${version}
        luarocks download ${name} ${version}
      ''
      + "\n")
    dependencies)}

    mv *.src.rock -t $out/luarocks
    luarocks-admin make-manifest --lua-version 5.1 $out/luarocks
    rm $out/luarocks/index.html
  ''
