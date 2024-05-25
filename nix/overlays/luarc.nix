{
  callPackage,
  installed-dependencies,
  lib,
  lua51Packages,
  mk-luarc,
  pkgs,
  self,
}: let
  luarc = mk-luarc {};
in
  luarc
  // {
    inherit (luarc) runtime;
    inherit (luarc.Lua) diagnostics globals;
    Lua.workspace = {
      inherit (luarc.Lua.workspace) ignoreDir;
      library = luarc.Lua.workspace.library ++ ["${installed-dependencies}/luarocks/share/lua/5.1/"];
    };
  }
