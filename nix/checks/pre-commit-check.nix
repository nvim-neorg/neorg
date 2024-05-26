{
  self,
  system,
  git-hooks,
}:
git-hooks.lib.${system}.run {
  src = "${self}";

  hooks = {
    alejandra.enable = true;
    luacheck.enable = true;
    # stylua.enable = true;
  };
}
