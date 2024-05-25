{
  self,
  git-hooks,
  pkgs,
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

      neorocks-test =
        (pkgs.neorocksTest {
          src = "${self}";
          name = "neorg";
          version = "scm-1";
          neovim = pkgs.neovim-unwrapped;
        })
        .overrideAttrs (oa:
          lib.recursiveUpdate oa {
            luarocksConfig = {
              rocks_servers = ["${pkgs.installed-dependencies}/luarocks"];
              rocks_trees = oa.luarocksConfig.rocks_trees ++ ["${pkgs.installed-dependencies}/luarocks" "."];
            };
          });
    };
  };
}
