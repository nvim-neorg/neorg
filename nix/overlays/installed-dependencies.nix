{
  lib,
  runCommand,
  lua51Packages,
  wget,
  self,
}: let
  dependencies = builtins.fromJSON (builtins.readFile "${self}/res/deps.json");
in
  runCommand "install-neorg-dependencies" {
    nativeBuildInputs = [lua51Packages.luarocks wget];
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-Z9hODJb/vNqa2OhAo8IuOLJWTaa/63mu0mVxAlAGJnA=";
  } ''
    mkdir $PWD/home
    export HOME=$PWD/home
    mkdir -p $out/luarocks

    ${lib.concatStrings (lib.mapAttrsToList (name: version:
      ''
        luarocks install --server="https://nvim-neorocks.github.io/rocks-binaries/" --tree="$out/luarocks" --force-lock --local ${name} ${version}
        luarocks download ${name} ${version}
      ''
      + "\n")
    dependencies)}

    mv *.src.rock -t $out/luarocks
    luarocks-admin make-manifest --lua-version 5.1 $out/luarocks
    rm $out/luarocks/index.html
  ''
