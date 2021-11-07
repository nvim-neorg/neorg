# Adding Your Own Spec of Colour to Neorg

### Customizing Highlights
Sometimes you'll find yourself wanting to modify the colours that Neorg comes with.
Thankfully this task isn't difficult! Let's take a look at how to do it.

### TreeSitter Highlight Groups
All of the highlight magic is done by the `core.highlights` module - this doesn't mean that
everything is configurable there though. TreeSitter highlight groups are actually configured
and defined in the `core.integrations.treesitter` module. `core.integrations.treesitter` uses
`core.highlights` under the hood but is separated so people who might not have TreeSitter enabled
can simply disable the `core.integrations.treesitter` module and not have the highlights present
at all. Let's change some highlights!

Inside of your `require('neorg').setup { load = { ... } }` table make sure to configure
`core.integrations.treesitter`:

```lua
require('neorg').setup {
    load = {
        ...,
        ["core.integrations.treesitter"] = {
            config = {
                highlights = {
                    <highlights go here>
                }
            }
        }
    }
}
```

You may be wondering what the default values are:
```lua
tag = {
    -- The + tells neorg to link to an existing hl
    begin = "+TSKeyword",

    -- Supply any arguments you would to :highlight here
    -- Example: ["end"] = "guifg=#93042b",
    ["end"] = "+TSKeyword",

    name = "+TSKeyword",
    parameters = "+TSType",
    content = "+Normal",
    comment = "+TSComment",
},

heading = {
    ["1"] = "+TSAttribute",
    ["2"] = "+TSLabel",
    ["3"] = "+TSMath",
    ["4"] = "+TSString",
},

error = "+TSError",

marker = {
    [""] = "+TSLabel",
    title = "+Normal",
},

drawer = {
    [""] = "+TSPunctDelimiter",
    title = "+TSMath",
    content = "+Normal"
},

escapesequence = "+TSType",

todoitem = {
    [""] = "+TSCharacter",
    pendingmark = "+TSNamespace",
    donemark = "+TSMethod",
},

unorderedlist = "+TSPunctDelimiter",

quote = {
    [""] = "+TSPunctDelimiter",
    content = "+TSPunctDelimiter",
}
```

You can change individual values without affecting anything else, for example if I want to change
the colour for a drawer title:

```lua
["core.integrations.treesitter"] = {
    config = {
        highlights = {
            drawer = {
                title = "+TSPunctDelimiter"
            }
        }
    }
}
```

The above code snippet will rebind the highlight group `NeorgDrawerTitle` to the `TSPunctDelimiter` highlight group.
If you don't want to bind to an existing hl group but instead want to make your own, omit the `+` symbol and simply
write some highlights (like you would with `:highlight`):

```lua
["core.integrations.treesitter"] = {
    config = {
        highlights = {
            drawer = {
                title = "guifg=#ffffff"
            }
        }
    }
}
```

**NOTE**: You may be starting to see a pattern here. Whenever you define a highlight as we have above the string "Neorg" is prepended
to the highlight group. Additionally nested tables concatenate, so:
```lua
highlights = {
    drawer = {
        title = "guifg=#ffffff"
    }
}
```

Evaluates to:
```
highlight! NeorgDrawerTitle guifg=#ffffff
```

## API Calls for `core.highlights`
- `trigger_highlights()` - goes through the publicly defined table of highlights and applies every highlight (i.e. creating them and linking them)
- `clear_highlights()` - completely clears all currently applied highlights
- `add_highlights(highlights)` - takes in a table of highlights and merges it into the main highlight table. Also invokes `trigger_highlights()` to apply them
