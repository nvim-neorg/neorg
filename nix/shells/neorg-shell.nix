{
  mkShell,
  luarc-to-json,
  luarc-with-dependencies,
  lua-language-server,
  stylua,
  lua51Packages,
  nil,
  lua5_1,
}:
mkShell {
  name = "neorg devShell";

  shellHook = ''
    ln -fs ${luarc-to-json luarc-with-dependencies} .luarc.json
  '';

  packages = [
    lua-language-server
    stylua
    lua51Packages.luacheck
    nil
    lua5_1
  ];
}
