# The Autocommand Module

The autocommand module allows anybody to receive an event upon an autocommand trigger.

Let's write a test module to show `core.autocommands` in action. This section assumes you have read the [Creating Modules](https://github.com/vhyrro/neorg/wiki/Creating-Modules) walkthrough.

```lua
--[[
--	A test module to enable autocommands.
--]]

require('neorg.modules.base')

local test = neorg.modules.create("test.module")

test.setup = function()
	return { success = true, requires = { "core.autocommands" } } -- Require the autocommands module
end

test.load = function()
	-- Enable the CursorHold autocommand
	-- All autocommands are disabled by default and need to be enabled manually
	test.required["core.autocommands"].enable_autocommand("CursorHold")
end

test.on_event = function(event)

	-- When the autocommand is enabled all subscribed modules will receive
	-- an event of type "core.autocommands.events.<autocmd_name>"
	-- Know that the name of the autocommand will always be in all lowercase
	if event.type == "core.autocommands.events.cursorhold" then
		require('neorg.external.log').info("We received a CursorHold event!")
	end

end

test.events.subscribed = {

	["core.autocommands"] = {
		cursorhold = true -- Subscribe to the autocommand event to receive it
	}

}
```

That's it! You can receive an event whenever a certain autocommand is triggered, nice. But that's not all.
By default, whenever you enable an autocommand, that autocommand will only trigger on \*.norg files. This
may not be what you want. To prevent them from being isolated, we can use `enable_autocommand`'s second parameter -
`dont_isolate`, which when set to true no longer isolates the autocommand to just norg files, but applies to all filetypes.
Whenever you receive an autocommand event, the event content will contain a single variable - `norg`. If true, the autocommand was triggered
from a \*.norg autocommand, else it was triggered through a global autocommand.

Here's an example:
```lua
--[[
--	A test module to enable autocommands.
--]]

require('neorg.modules.base')

local test = neorg.modules.create("test.module")

test.setup = function()
	return { success = true, requires = { "core.autocommands" } } -- Require the autocommands module
end

test.load = function()
	-- Enable the CursorHold autocommand
	-- Make the autocommand trigger on all filetypes
	test.required["core.autocommands"].enable_autocommand("CursorHold", true)
end

test.on_event = function(event)

	-- Note how we also check for `event.content.norg`
	if event.type == "core.autocommands.events.cursorhold" and not event.content.norg then
		require('neorg.external.log').info("We received a CursorHold event from any file!")
	end

end

test.events.subscribed = {

	["core.autocommands"] = {
		cursorhold = true -- Subscribe to the autocommand event to receive it
	}

}
```

The above code will only print a message whenever we receive a global CursorHold autocommand.
