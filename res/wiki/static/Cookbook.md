# Neorg Cookbook

This document details a bunch of snippets and prebuilt configurations for individual modules
for a just works experience.

> [!TIP]
> If you're looking for a quickstart setup to get you started with Neorg, check out the [kickstart page](https://github.com/nvim-neorg/neorg/wiki/Kickstart) instead.

## Completion with `nvim-cmp`

### Requirements
- [`nvim-cmp`](https://github.com/hrsh7th/nvim-cmp)

### Steps

1. In your Neorg configuration:
   ```lua
   load = {
       ["core.defaults"] = {},
       ["core.completion"] = {
           config = {
               engine = "nvim-cmp",
           }
       },
       ["core.integrations.nvim-cmp"] = {},
   }
   ```

2. In your `nvim-cmp` configuration:
   ```lua
   sources = cmp.config.sources({
       -- ... your other sources here
       { name = "neorg" },
   })
   ```

## Latex Rendering

Currently, there are 2 options for rendering latex inline in .norg files
One revolves around [`image.nvim`](https://github.com/3rd/image.nvim), and the other around [`snacks.nvim`](https://github.com/folke/snacks.nvim)
Due to recent changes in the `image.nvim` api, it has been recommended to use `snacks.nvim` for the time being, until it is integrated directly into neorg

### Requirements
- A terminal with kitty graphics protocol support (kitty/ghostty)
- Either [`image.nvim`](https://github.com/3rd/image.nvim) or [`snacks.nvim`](https://github.com/folke/snacks.nvim) installed and set up

### Steps for native rendering with `image.nvim`

1. In your Neorg configuration:
   ```lua
   load = {
       ["core.integrations.image"] = {},
       ["core.latex.renderer"] = {},
   }
   ```

2. Place some maths within maths blocks (`$| ... |$`):
   ```norg
   $|Hello, \LaTeX|$
   ```
3. Run `:Neorg render-latex`.

### Steps for inline rendering with `snacks.nvim`

1. Install a latex renderer with the dependancies listed in the [`snacks.nvim`](https://github.com/folke/snacks.nvim) repo
   This is covered by the `texlive-full` package on the AUR
   You will also need to install `imagemagick`

2. Make sure that `snacks.image` is enabled
   ```lua
   -- lazy.nvim
   {
       "folke/snacks.nvim",
       opts = {
           image = {
               enabled = true,
           }
       }
   }
   ```

3. Use standard markdown to insert latex (`$...$` or `$$...$$` for multi-line, as the math block is still not implemented)
   ```norg
   $Hello, \LaTeX$
   ```
   There is no need for the `|` characters, as `snacks.nvim` allows for arbitrary spaces by default
   This method has the added benefit of rendering latex in all files that support it, such as markdown and normal `.tex` files

To debug, please refer to the debug section of the [`snacks.image options`](https://github.com/folke/snacks.nvim/blob/main/docs/image.md#%EF%B8%8F-config)
