{
  self,
  git-hooks,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks = {
      type-check = git-hooks.lib.${system}.run {
        src = "${self}/lua";

        hooks = {
          lua-ls = {
            enable = true;
            settings.configuration = pkgs.luarc-with-dependencies;
          };
        };
      };

      pre-commit-check = git-hooks.lib.${system}.run {
        src = "${self}";

        hooks = {
          alejandra.enable = true;
          luacheck.enable = true;
          # stylua.enable = true;
        };
      };
    };
  };
}
