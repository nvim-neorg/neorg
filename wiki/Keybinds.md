# The Keybinds Module

The `core.keybinds` module allows any other module to bind events to keypresses. 

Let's write a test module to show `core.keybinds` in action. This section assumes you have read the [Creating Modules](https://github.com/vhyrro/neorg/wiki/Creating-Modules) walkthrough.

```lua
--[[
--	A test module to enable keybindings.
--]]

require('neorg.modules.base')

local test = neorg.modules.create("test.module")

test.setup = function()
	return { success = true, requires = { "core.keybinds" } } -- Require the keybinds module
end

test.load = function()
	module.required["core.keybinds"].register_keybind(test.name, "my_keybind")
end

test.on_event = function(event)

	-- If you're confused here, see the explanation below this code snippet
	if event.split_type[2] == "test.module.my_keybind" then
		require('neorg.external.log').info("Keybind my_keybind has been pressed!")
	end

end

test.events.subscribed = {

	["core.keybinds"] = {
		["test.module.my_keybind"] = true -- Subscribe to the event
	}

}
```

### What's happening here?
The process of defining a keybind is only a tiny bit more involved than defining e.g. an autocommand.
Let's see what differs in creating a keybind rather than creating an autocommand:

- The event path - the event path is a bit different here than it is normally. Whenever you receive an event, you're used to the path looking like this: `<module_path>.events.<event_name>`. Here, however, the path looks like this: `<module_path>.events.test.module.<event_name>`. 
Why is that? Well, the module operates a bit differently under the hood. In order to create a unique name for every keybind we use the module's name as well.
Meaning if your module is called `test.module` you will receive an event of type `<module_path>.events.test.module.<event_name>`.
- `event.split_type[2]` - The `split_type` field is the `type` field except split into two. The split point is `.events.`, meaning if the event type is e.g. "core.keybinds.events.test.module.my_keybind" the value of `split_type` will be `{ "core.keybinds", "test.module.my_keybind" }`.

Now, we must bind this key somewhere! Neorg does not actually create any keybinds - that's up to the user.
Neorg used to do this, but we later realized that this was an awful idea for several reasons that aren't in the scope of this document.
Just know that it was very verbose, ugly, and disorganized.

`core.keybinds` automatically requires `core.neorgcmd` as a dependency, and you can read more about that module [here](https://github.com/vhyrro/neorg/wiki/Neorg-Command).
To invoke a keybind, we can then use `:Neorg keybind norg test.module.my_keybind`.
`:Neorg keybind` tells `core.neorgcmd` to invoke a keybind, and the next argument (`norg`) is the *mode* that the keybind should be executed in.
Modes are a way to isolate different parts of the neorg environment easily, this includes keybinds too.
`core.mode`, the module designed to manage modes, is explained in the [Creating Modules](https://github.com/vhyrro/neorg/wiki/Creating-Modules#creating-custom-modes) file and in its own page.
Just know that by default neorg launches into the `norg` mode, so you'd most likely want to bind to that.
After the mode you can find the path to the keybind we want to trigger. Soo let's bind it! You should have already read the [user keybinds](https://github.com/vhyrro/neorg/wiki/User-Keybinds#keybind-megalist)
document that details where and how to bind keys, the below code snippet is an extension of that:

`<somewhere in your own config>`
```lua
-- Require the user callbacks module, which allows us to tap into the core of Neorg
local neorg_callbacks = require('neorg.callbacks')

-- Listen for the enable_keybinds event, which signals a "ready" state meaning we can bind keys.
-- This hook will be called several times, e.g. whenever the Neorg Mode changes or an event that
-- needs to reevaluate all the bound keys is invoked
neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybinds)

	-- All your other keybinds

	-- Map all the below keybinds only when the "norg" mode is active
	keybinds.map_event_to_mode("norg", {
		n = {
			{ "<Leader>o", "test.module.my_keybind" }
		}
	}, { silent = true, noremap = true })

end)
```

Thanks to the above code snippet you should now have working keybinds, as you'd expect!

To change the current mode as a user of neorg you can run `:Neorg set-mode <mode>`. If you try changing the current mode into a non-existent mode (like `:Neorg set-mode a-nonexistent-mode`)
you will see that all the keybinds you bound to the `norg` mode won't work anymore! They'll start working again if you reset the mode back via `:Neorg set-mode norg`.

# Extra Bits
It is also possible to mass initialize keybindings via the public `register_keybinds` function. It can be used like so:

```lua
test.load = function()
	module.required["core.keybinds"].register_keybinds(test.name, { "my_keybind", "my_other_keybind" })
end
```

This should stop redundant calls to the same function or loops within module code.
