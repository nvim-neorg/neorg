# AUTOCOMMAND MODULE FOR NEORG

This module exposes functionality for subscribing to autocommands and performing actions based on those autocommands

## USAGE

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
