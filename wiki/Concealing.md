# The `core.norg.concealer` module
The module that is responsible for making your experience just that little bit better.

The concealer module converts certain patterns of text into clean icons that represent said text in some way.
Let's see how we can configure this module to our liking.

### Configuration Options
The concealer module allows you to enable certain conceals (or "beautifications") and disable others. It also allows you to change the icons.

Configuration:
```lua
icons = {
    todo = {
        enabled = true, -- Conceal TODO items

        done = {
            enabled = true, -- Conceal whenever an item is marked as done
            icon = ""
        },
        pending = {
            enabled = true, -- Conceal whenever an item is marked as pending
            icon = ""
        },
        undone = {
            enabled = true, -- Conceal whenever an item is marked as undone
            icon = "×"
        }
    },
    quote = {
        enabled = true, -- Conceal quotes
        icon = "∣"
    },
    heading = {
        enabled = true, -- Enable beautified headings

        -- Define icons for all the different heading levels
        level_1 = {
            enabled = true,
            icon = "◉",
        },

        level_2 = {
            enabled = true,
            icon = "○",
        },

        level_3 = {
            enabled = true,
            icon = "✿",
        },

        level_4 = {
            enabled = true,
            icon = "•",
        },
    },
    marker = {
        enabled = true, -- Enable the beautification of markers
        icon = "",
    },
},
```

### Troubleshooting
There may be a high chance that the default icons do not work on your system. Please be sure to install
`Nerd Fonts`. An automated script to install them for you can be found [here](https://github.com/ronniedroid/getnf).
Otherwise change the provided icons to something that *does* get rendered for you properly.

### Nerdy stuff
Apart from being able to disable and modify existing icons you can also add your own!
Adding your own is just a bit more complex, so let's explain:
```lua
icons = {
    heading = {
        level_5 = {
            enabled = true,
            icon = "◦",
            pattern = "^(%s*)%*%*%*%*%*%s+",
            whitespace_index = 1,
            highlight = "TSBoolean",
            padding_before = 4,
        }
    }
}
```

The above code snippet adds an icon for a level-5 heading. How does it work? Before we get into it note that you must
define *all* the variables you see above (otherwise you will get some rather uninformative errors).

Let's begin:
- `enable` - describes whether or not the current icon should be enabled
- `icon` - the icon to replace the specified text with
- `pattern` - a regex pattern that must be matched in order for the icon to be triggered
- `whitespace_index` - the ID of a capture from `pattern` signifying the "prefix" or the prepending whitespace.
  This may sound a little confusing. You'll see that in our `pattern` we create a capture `(%s*)`. Since that is the first
  capture of `pattern` we set `whitespace_index` to 1. This is later used to calculate where to place the icon.
- `highlight` - the name of a highlight group to bind to (allows for a coloured icon)
- `padding_before` - the amount of extra invisible padding to add in front of the icon. We set this to `4` so that
  out of the 5 asterisks in a level-5 heading (`*****`) `4` of them will be hidden away with padding and the 5th one
  will be overlayed with the icon.

### API Functions
`core.norg.concealer` also comes with a few API functions:
- `trigger_conceal()` - reads the table of icons and attempts to match every line in the buffer for a potential conceal,
                        should only be done when reparsing an entire buffer.
- `update_current_line()` - reads the table of icons and attempts to update the current line's conceals. Useful if you don't
  want to reparse the entire file.
- `set_conceal(line_number, line)` - attempts to set a conceal on the specified line:
  - `line_number` - the line number to apply the conceal on
  - `line` - the content of the line at the specified line number
- `_set_extmark(text, highlight, line_number, start_column, end_column)` - internal function, should not be used
- `clear_conceal()` - clears all conceals in the current buffer (clears the `neorg_conceals` namespace)
