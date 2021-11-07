<div align="center">

# Configuring Modules in Neorg

A small guide

</div>

---

# Configuring our First Module!
Each module exposes something called the `config` table. This table can be overridden by any user from within the `require('neorg').setup()` function. Let's see it in action!

Let's suppose we have a module called `core.test`. Let's also say it has its own custom github with a README. In that README, the following is said:

> Configuration:
```lua
config = {

	my_special_value = true,

	some_other_value = {}

}
```

What does it mean by this? Let's take a look at an example neorg configuration:

```lua
use { 'vhyrro/neorg', config = function()
	
	require('neorg').setup {
		load = {
			["core.test"] = {}
		}
	}

end}
```

You should be familiar with the above code snippet. If you aren't, see [here](https://github.com/vhyrro/neorg/wiki/Installation).
Did it ever strike you as weird that we define each module as a table, rather than something like a true/false boolean? This is because this is where you define your configs of course!

Take a look at this code snippet:
```lua
use { 'vhyrro/neorg', config = function()

	require('neorg').setup {
		load = {
			["core.test"] = {
				config = {
					my_special_value = false
				}
			}
		}
	}

end}
```

Can you get an idea of how it works? If a module exposes some configuration options, they can be changed on a per-module basis and will override the default values (in our case `my_special_value` was true, but we overrode it to false). If a certain value isn't overriden in the `config` table then it will stay as the default.

So if a module's README ever tells you its configuration options, now you know how to change them!
