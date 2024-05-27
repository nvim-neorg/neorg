{pkgs, ...}: {
  devShells.default = pkgs.mkShell {
    name = "neorg devShell";

    shellHook = ''
      ln -fs ${pkgs.luarc-to-json pkgs.luarc-with-dependencies} .luarc.json
    '';

    packages = with pkgs; [
      lua-language-server
      stylua
      lua51Packages.luacheck
      nil
      lua5_1
    ];
  };
}
