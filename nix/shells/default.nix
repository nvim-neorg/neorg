{pkgs, ...}: {
  devShells.default = pkgs.mkShell {
    name = "neorg devShell";

    shellHook = ''
      ln -fs ${pkgs.luarc-to-json pkgs.luarc-with-dependencies} .luarc.json
    '';

    packages = with pkgs; [
      lua-language-server
      stylua
      luajitPackages.luacheck
      nil
      lux-cli
      luajitPackages.lux-lua
    ];
  };
}
