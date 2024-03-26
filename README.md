<div align="center">

<img src="res/neorg.svg" width=300>

# Neorg - An Organized Future

<a href="https://neovim.io"> ![Neovim](https://img.shields.io/badge/Neovim%200.8+-brightgreen?style=for-the-badge) </a>
<a href="https://discord.gg/T6EgTAX7ht"> ![Discord](https://img.shields.io/badge/discord-join-7289da?style=for-the-badge&logo=discord) </a>
<a href="/LICENSE"> ![License](https://img.shields.io/badge/license-GPL%20v3-brightgreen?style=for-the-badge)</a>
<a href="https://dotfyle.com/plugins/nvim-neorg/neorg"> ![Usage](https://dotfyle.com/plugins/nvim-neorg/neorg/shield?style=for-the-badge) </a>

Your New Life Organization Tool - All in Lua

[Summary](#summary)
•
[Tutorial](#-tutorial)
•
[Installation](#-installationquickstart)
•
[Setup](#-setup)
•
[Usage](#-usage)
<br>
[Modules](#-modules)
•
[Roadmap](/ROADMAP.md)
•
[Philosophy](#-philosophy)
•
[FAQ](#-faq)

</div>

<div align="center">

<br>

**:warning: Neorg `8.0.0` has introduced some breaking changes! Please see [this blog post](https://vhyrro.github.io/posts/neorg-and-luarocks/) on how to migrate.**

## Summary

</div>

Neorg (_Neo_ - new, _org_ - organization) is a Neovim plugin designed to reimagine organization as you know it.
Grab some coffee, start writing some notes, let your editor handle the rest.

### What is Neorg?

Neorg is an all-encompassing tool based around structured note taking, project and task management, time
tracking, slideshows, writing typeset documents and much more. The premise is that all of these features are
built on top of a single base file format (`.norg`), which the user only has to learn once to gain access to
all of Neorg's functionality.

Not only does this yield a low barrier for entry for new users it also ensures that all features are integrated with each
other and speak the same underlying language. The file format is built to be expressive and easy to parse,
which also makes `.norg` files easily usable anywhere outside of Neorg itself.

A good way of thinking about Neorg is as a plaintext environment which can be adapted to a variety of use cases.
If a problem can be represented using raw text, it can be solved using Neorg.

###### :exclamation: **IMPORTANT**: Neorg is young software. We consider it stable however be prepared for occasional breaking workflow changes. Make sure to pin the version of Neorg you'd like to use and only update when you are ready.

## 🌟 Tutorial

A video tutorial may be found on Youtube:

<div>

<a href="https://www.youtube.com/watch?v=NnmRVY22Lq8&list=PLx2ksyallYzVI8CN1JMXhEf62j2AijeDa&index=1">
 <img src="https://img.youtube.com/vi/NnmRVY22Lq8/0.jpg" style="width:75%;">
</a>

</div>

## 📦 Installation

Neorg's setup process is slightly more complex than average, so we encourage you to be patient :)

### `rocks.nvim`

The recommended installation method is via [rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim).

<details open>
<summary>Installation snippet.</summary>

- Run `:Rocks install rocks-config.nvim` (if you don't have it already!).
- Run `:Rocks install neorg`.
- Add the following to your config's `lua/plugins/neorg.lua`:
  ```lua
  require("neorg").setup()
  ```

</details>

### `lazy.nvim`

In order to install Neorg via `lazy.nvim`, you must take a few extra steps - this is because `luarocks` is a critical component for Neorg to function.
See [this blog](https://vhyrro.github.io/posts/neorg-and-luarocks/) for more information.

> [!IMPORTANT]
> Using luarocks Neorg will install itself and these dependencies with their respective versions:
> - `lua-utils.nvim`
> - `nvim-nio`
> - `nui.nvim`
> - `plenary.nvim`

<details>
<summary>Click for installation snippet.</summary>

- Ensure you have `vhyrro/luarocks.nvim` installed:
  ```lua
  {
      "vhyrro/luarocks.nvim",
      priority = 1000,
      config = true,
  }
  ```
- Add the following to your plugin list:
  ```lua
  {
      "nvim-neorg/neorg",
      dependencies = { "luarocks.nvim" },
      lazy = false, -- Disable lazy loading as some `lazy.nvim` distributions set `lazy = true` by default
      version = "*", -- Pin Neorg to the latest stable release
      config = true,
  }
  ```

</details>

### `packer.nvim`

Neorg can be installed purely via luarocks on packer, pulling in all required dependencies in the process.

It is not recommended to use packer as it is now unmaintained.

<details>
<summary>Click for installation snippet.</summary>

```lua
use {
  "nvim-neorg/neorg",
  rocks = { "lua-utils.nvim", "nvim-nio", "nui.nvim", "plenary.nvim" },
  tag = "*", -- Pin Neorg to the latest stable release
  config = function()
      require("neorg").setup()
  end,
}
```

</details>

### Other Plugin Managers

Because of the complexities of `luarocks` we are choosing not to supported other plugin managers for the time
being. It is actively on our TODO list, however!

## 📚 Further Learning

After you have installed Neorg, we recommend you head over to either the Youtube tutorial series or to the [wiki](https://github.com/nvim-neorg/neorg/wiki)!

## Credits

Massive shoutouts go to all the contributors actively working on the project together to form a fantastic
integrated workflow:

- [mrossinek](https://github.com/mrossinek) - for basically being my second brain when it comes to developing new features
  and adding new syntax elements
- [danymat](https://github.com/danymat) - for creating the excellent foundations for the up and coming GTD system

And an extra thank you to:

- [Binx](https://github.com/dvchoudh) - for making that gorgeous logo for free!
- [bandithedoge](https://github.com/bandithedoge) - for converting the PNG version of the logo into SVG form

## Support

Love what I do? Want to see more get done faster? Want to support future projects? Any sort of support is always
heartwarming and fuels the urge to keep going :heart:. You can show support here:

- [Buy me a coffee!](https://buymeacoffee.com/vhyrro)
- [Support me via Github Sponsors](https://github.com/sponsors/vhyrro)
- [Support me on Patreon](https://patreon.com/vhyrro)

Immense thank you to all of the sponsors of my work!

<div align="center">

<!-- sponsors --><a href="https://github.com/vsedov"><img src="https://github.com/vsedov.png" width="60px" alt="vsedov" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/skbolton"><img src="https://github.com/skbolton.png" width="60px" alt="skbolton" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/molleweide"><img src="https://github.com/molleweide.png" width="60px" alt="molleweide" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/danymat"><img src="https://github.com/danymat.png" width="60px" alt="danymat" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/theherk"><img src="https://github.com/theherk.png" width="60px" alt="theherk" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/purepani"><img src="https://github.com/purepani.png" width="60px" alt="purepani" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/refaelsh"><img src="https://github.com/refaelsh.png" width="60px" alt="refaelsh" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/tromars"><img src="https://github.com/tromars.png" width="60px" alt="tromars" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/jgregoire"><img src="https://github.com/jgregoire.png" width="60px" alt="jgregoire" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/bottd"><img src="https://github.com/bottd.png" width="60px" alt="bottd" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/DingDean"><img src="https://github.com/DingDean.png" width="60px" alt="DingDean" /></a>&nbsp;&nbsp;&nbsp;<a href="https://github.com/Ladas552"><img src="https://github.com/Ladas552.png" width="60px" alt="Ladas552" /></a>&nbsp;&nbsp;&nbsp;<!-- sponsors -->

</div>
