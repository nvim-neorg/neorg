# The :Neorg Command

The `core.neorgcmd` module allows any other module to add its own custom commands to the `:Neorg` command.
Think of it as a bridge between you and `:Neorg`.

Let's write a test module to show `core.neorgcmd` in action. This section assumes you have read the [Creating Modules](https://github.com/vhyrro/neorg/wiki/Creating-Modules) walkthrough.

---

```lua
--[[
	A test module to check out the capabilities of core.neorgcmd
--]]

require('neorg.modules.base')

local module = neorg.modules.create("test.module")

local log = require('neorg.external.log')

module.setup = function()
	return { success = true, requires = { "core.neorgcmd" } }
end

module.load = function()
	module.required["core.neorgcmd"].add_commands_from_table({
		definitions = {
			test_command = {
				test_subcommand = {},
				another_subcommand = {}
			}
		},
		data = {
			test_command = {
				args = 1,

				subcommands = {
					test_subcommand = {
						min_args = 2,
						name = "our.test_command"
					},
					another_subcommand = {
						max_args = 2,
						name = "our.other_command"
					}
				}
			}
		}
	})
end

module.on_event = function(event)
	if event.split_type[1] == "core.neorgcmd" then
		if event.split_type[2] == "our.test_command" then
			log.info("We received a test subcommand!")
		elseif event.split_type[2] == "our.other_command" then
			log.info("We received another test subcommand!")
		end
	end
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		["our.test_command"] = true,
		["our.other_command"] = true
	}
}

return module
```

There's a lot to cover, so sit tight!

### The setup
The setup is very basic, all we have to do is tell neorg that this module `requires core.neorgcmd` and we're good to go.

After that we set up the command structure.

### Command Definitions
There are several ways to define new command for `core.neorgcmd`, but we'll focus on the first method for now.

By using `core.neorgcmd.add_commands_from_table()` you can supply commands for neorgcmd to create. Let's analyze this structure.

The `definitions` table - this table is used for custom completion. It's structured in an easy-to-understand way, where the top-level table represents a command and all subtables represent subcommands.

The `data` table - this table's a lot more complex, so let's explain it. This table must follow the same layout as `definitions` in terms of commands and subcommands, but it has a different structure. Here we expose metadata about our commands. Let's break it down further:
```lua
data = {
	-- We define our main command here
	test_command = {
		args = 1, -- We tell neorgcmd that this command MUST take in only one argument, no more, no less. "args" overwrites both min_args and max_args

		subcommands = { -- We define subcommands of this command here
			test_subcommand = {
				min_args = 2, -- We tell neorgcmd that this command requires AT LEAST 2 arguments, although any number of arguments is allowed
				name = "our.test_command" -- An arbitrary (but unique) name for the command
			},
			another_subcommand = {
				max_args = 2, -- Tells neorgcmd that this command can take from 0-2 arguments AT MOST
				name = "our.other_command" -- An arbitrary (but unique) name for the command

			--[[
				If we had extra subcommands for this command we would create another
				"subcommands" table and continue the cycle again.
				Since we don't have any more subcommands we DO NOT define the "subcommands"
				table at all. Defining it is enough for neorgcmd to attempt to recursively
				search that table as well, causing errors.
			--]]
			}
		}
	}
}
```

As mentioned before, note that this table must follow the exact same structure as `definitions`: `test_command -> { test_subcommand, another_subcommand }` (for `definitions`) and `test_command -> subcommands -> { test_subcommand, another_subcommand }` (for `data`).

**NOTE**: each callable command *must* have a `name` field associated with it. A not-so-insightful error message will appear if you mess up here.

### Reacting to a Command
Cool, we've defined our commands. What next? How do we handle callbacks from such a function? Via events, of course!

After the commands are read, their respective events are dynamically generated. The name of the event that we receive is very easy to remember because it uses the `name` field! It looks like this: `core.neorgcmd.events.<name>`.
Meaning if we gave our command a `name` of `my.plugin.test`, we would receive an event of path `core.neorgcmd.events.my.plugin.test`. Easy enough!

All that's left for us to do at that point is subscribe to both events and we're good to go.

### Arguments
As you should know already, the amount of arguments allowed can be defined in the `data` table. How do we read our arguments though? Easy, all arguments will be given to us when we receive our event in the `event.content` table in the form of a string array.
You can try printing them out through the logger to inspect the contents if you wish:
```lua
module.on_event = function(event)
	if event.split_type[1] == "core.neorgcmd" then
		log.info(event.content) -- Print the content table
	end
end
```

Try running `:Neorg test_command test_subcommand my args` and see for yourself! If it doesn't work, make sure to set the logger level to at least "info" or "trace"! See [configuring the logger](https://github.com/vhyrro/neorg/wiki/Installation#configuring-the-logger).

# Other Methods of Adding Commands
There's a couple more methods of adding commands, let's discuss them!
- Adding by module - it's possible to store your commands inside the `module.public.neorg_commands` table instead of passing them into `add_command_from_table()`. After all modules are initialized `core.neorgcmd` will automatically search for this table and automagically apply all of its contents! Pretty neat, eh?
- Adding by command module - there's an extra bit of info you should accomodate yourself with - **command modules**. These are regular modules but are stored in a special directory: `neorg/modules/core/neorgcmd/commands/`. They can be loaded easily, like so:
```lua
require('neorg').setup {

	load = {
		["core.neorgcmd"] = {
			config = {
				load = { -- Loads modules from the core.neorgcmd.commands directory!
					"my.custom.command", -- Note that these are relative paths
					"some.other.command"
				}
			}
		}
	}

}
```
Those modules must have a `module.public.neorg_commands` table and will be managed and loaded by `core.neorgcmd` itself.
Apart from the `load` table you also have `core.neorgcmd.public.add_commands_from_file(module_name)` which achieves the exact same thing as loading a command module via the `load` table. Note that the `module_name` parameter takes in the same relative path as the `load` table would. `add_commands_from_file()` also loads the module if it's not available.
- Adding via `add_commands(module_name)` - this command probably shouldn't be used, but it's here anyway. It takes in an absolute path to a module and parses its `neorg_commands` table. The reason this command has no real use is that after all modules are loaded `core.neorgcmd` will automatically perform this step for you, but oh well, it could be useful for when you dynamically load a module later on in the neorg lifetime and want it to be parsed.

Using the naming system you can create aliases to commands if you wish. As long as your alias and the command you want to alias to have the same `name` associated with them they will be treated as the same command.

# Still Got Questions?
You can create an issue if you need further explanation, but more preferably you can come ask on [the discord](https://discord.gg/T6EgTAX7ht)!
