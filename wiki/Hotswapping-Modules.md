# Hotswapping Modules in Neorg
Overwriting the core of Neorg by yourself.

## What is Hotswapping?
Hotswapping is the process of replacing a certain module with your own custom "clone" of it. Your clone should retain the same functionality as the previous module you hotswapped. Let's discuss how such hotswapping is possible in neorg.

### Hotswapping a module
In order to hotswap a module, we need to have a module to replace! Let's say, hypothetically, we want to replace
`core.norg.dirman`, how would we do it?

```lua
--[[
	This module is an example module for the Neorg wiki!
	It's supposed to demonstrate module hotswapping.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("test.module")

module.setup = function()
	return { success = true, replaces = "core.norg.dirman", replace_merge = true }
end

return module
```

... That's it! That's how easy it is to hotswap any other module. Let's discuss:
- The `replaces` value tells neorg which module to hotswap - note that if the module is not loaded our current module gets loaded in its place, otherwise the previous module gets unloaded and then the swap happens. After the swap, the name of our current module will be set to the one we hotswapped to, meaning after the swap our module name will be `core.norg.dirman`.
- The `replace_merge` value is a pretty nifty feature - when set to `true`, it will transfer all of the data from the previously loaded module (the one we wanted to hotswap to) and transfer it to our module. This means you don't need to start fresh after hotswapping, but you can instead continue where the previous module left off.

Be weary though, you want to support 100% of all the functions and configuration options the original module exposed, so users don't have to go through the process of setting
nonstandard config options and calling invalid API functions. The actual logic of those functions can be different though, as long as the return value is in the same format as the original
so that other modules keep working.

### Bugs
Currently, the hotswapping feature hasn't been that extensively tested, and there may be issues I could've overlooked. If you find these issue, be sure to report them to me!
