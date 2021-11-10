# The `core.autocommands` Module

## Summary
Handles the creation and management of Neovim's autocommands.

## Overview
This module exposes functionality for subscribing to autocommands and performing actions based on those autocommands.

In your `module.setup()`, make sure to require core.autocommands (requires = { "core.autocommands" })
Afterwards in a function of your choice that gets called *after* core.autocommmands gets intialized e.g. load():

```lua
module.load = function()
    module.required["core.autocommands"].enable_autocommand("VimLeavePre") -- Substitute VimLeavePre for any valid neovim autocommand
end
```

Afterwards, be sure to subscribe to the event:

```lua
module.events.subscribed = {

    ["core.autocommands"] = {
        vimleavepre = true
    }

}
```

Upon receiving an event, it will come in this format:
```lua
{
    type = "core.autocommands.events.<name of autocommand, e.g. vimleavepre>",
    broadcast = true
}
```

## Usage
### How to Apply
- This module is already present in the [`core.defaults`](https://github.com/nvim-neorg/neorg/wiki/Defaults) metamodule.
  You can load the module with:
  ```lua
  ["core.defaults"] = {},
  ```
  In your Neorg setup.
- To manually load the module, place this code in your Neorg setup:
  ```lua
  ["core.autocommands"] = {
     config = { -- Note that this table is optional and doesn't need to be provided
         -- Configuration here
     }
  }
  ```
  Consult the [configuration](#Configuration) section to see how you can configure `core.autocommands` to your liking.

### Configuration
No configuration provided
## Developer Usage
### Public API
This segment will detail all of the functions `core.autocommands` exposes. All of these functions reside in the `public` table.

- `enable_autocommand`

### Examples
#### Binding to an Autocommand
```lua
local mymodule = neorg.modules.create("my.module")

mymodule.setup = function()
    return {
        success = true,
        requires = {
            "core.autocommands", -- Be sure to require the module!
        },
    }
end

mymodule.load = function()
    -- Enable an autocommand (in this case InsertLeave)
    module.required["core.autocommands"].enable_autocommand("InsertLeave")
end

-- Listen for any incoming events
mymodule.on_event = function(event)
    -- If it's the event we're looking for then do something!
    if event.type == "core.autocommands.events.insertleave" then
        log.warn("We left insert mode!")
    end
end

mymodule.events.subscribed = {
    ["core.autocommands"] = {
        insertleave = true, -- Be sure to listen in for this event!
    },
}

return mymodule
```


## Extra Info
### Version
This module supports at least version **0.0.8**.
The current Neorg version is **0.0.8**.

### Requires
This module does not require any other modules to operate.
