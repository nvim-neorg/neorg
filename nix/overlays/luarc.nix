{
  callPackage,
  installed-dependencies,
  lib,
  lua51Packages,
  mk-luarc,
  self,
}: let
  luarc = mk-luarc {};
in
  lib.recursiveUpdate luarc
  {
    Lua.workspace.library = luarc.Lua.workspace.library ++ ["${installed-dependencies}/luarocks/share/lua/5.1/"];
  }
