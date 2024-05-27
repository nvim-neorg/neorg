{
  lib,
  self,
  mk-luarc,
  runCommand,
  lua51Packages,
  wget,
}: let
  luarc = mk-luarc {};

  dependencies = builtins.fromJSON (builtins.readFile "${self}/res/deps.json");

  install-dependencies =
    runCommand "install-neorg-dependencies" {
      nativeBuildInputs = [lua51Packages.luarocks wget];
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = "sha256-SOsIgtmkXTKMZrKUHHzAf+XAshl/J7+DN9RFeLz+DDY=";
    } ''
      mkdir $PWD/home
      export HOME=$PWD/home
      mkdir -p $out/luarocks

      ${lib.concatStrings (lib.mapAttrsToList (name: version: ''luarocks install --tree="$out/luarocks" --force-lock --local ${name} ${version} '' + "\n") dependencies)}
    '';
in
  luarc
  // {
    inherit (luarc) runtime;
    inherit (luarc.Lua) diagnostics globals;
    Lua.workspace = {
      inherit (luarc.Lua.workspace) ignoreDir;
      library = luarc.Lua.workspace.library ++ ["${install-dependencies}/luarocks/share/lua/5.1/"];
    };
  }
