{
  self,
  system,
  git-hooks,
  luarc-with-dependencies,
}:
git-hooks.lib.${system}.run {
  src = "${self}/lua";

  hooks = {
    lua-ls = {
      enable = true;
      settings.configuration = luarc-with-dependencies;
    };
  };
}
