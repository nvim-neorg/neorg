# Neorg Cookbook

This document details a bunch of snippets and prebuilt configurations for individual modules
for a just works experience.

> [!TIP]
> If you're looking for a quickstart setup to get you started with Neorg, check out the [kickstart page](https://github.com/nvim-neorg/neorg/wiki/) instead.

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

### Requirements
- A terminal with kitty graphics protocol support (kitty/ghostty)
- [`image.nvim`](https://github.com/3rd/image.nvim) installed and set up

### Steps

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
