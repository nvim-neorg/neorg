{
  pkgs,
  lib,
  config,
  inputs,
  gen-luarc,
  ...
}: let
  neorg-dependencies = builtins.fromJSON (builtins.readFile ./res/deps.json);
  luarc = pkgs.mk-luarc {
    plugins = builtins.attrNames neorg-dependencies;
  };
in {
  name = "neorg";

  languages.lua = {
    enable = true;
    package = pkgs.luajit;
  };

  # Set up packages for the developer and testing environment. Explanation of some packages:
  # - `tree-sitter` - for `tree-sitter-build` to work
  # - `imagemagick` - for testing `image.nvim` integrations
  packages = with pkgs; [imagemagick git wget tree-sitter gcc luajitPackages.luarocks luajitPackages.magick];

  enterShell =
    # TODO(vhyrro): Hook these up to the user's Neovim instance (somehow) | lib.attrsets.foldlAttrs (acc: name: version: "luarocks install --force-lock --local ${name} ${version}" + "\n" + acc) "" neorg-dependencies +
    ''
      ln -fs ${pkgs.luarc-to-json luarc} .luarc.json
    '';

  enterTest = ''
    nvim --headless -u ./res/kickstart.lua example.norg -c wq
    if [ ! -f example.norg ]; then
      echo "Integration test failed!"
      exit 1
    fi
    rm example.norg
  '';
}
