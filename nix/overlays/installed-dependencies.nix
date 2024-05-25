{
  lib,
  pkgs,
  self,
}: let
  dependencies = builtins.fromJSON (builtins.readFile "${self}/res/deps.json");
in
  pkgs.runCommand "install-neorg-dependencies" {
    nativeBuildInputs = with pkgs; [lua51Packages.luarocks wget];
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
