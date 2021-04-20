<div align="center">

# Creating Modules for Neorg
The magic behind the scenes, or in other words understanding the inner workings of neorg.

</div>

---

Table of Contents:
  - [Understanding the file tree](#understanding-the-file-tree)
  - [Introduction to modules](#introduction-to-modules)
  - [Writing a barebones neorg module](#writing-a-barebones-neorg-module)
  - [Introduction to events](#events---an-introduction)
  - [Broadcasting an event](#defining-and-broadcasting-our-own-event)
  - [Configuring modules](#configuration)
  - Inbuilt modules:
    - The core.autocommands module
    - The core.keybinds module
  - Publishing our module to github and downloading it from there

---

Just a small note that certain things might not make full sense yet, I'm working on it to make it better! Hope you stick with me :D

# Understanding the File Tree
```
lua/
├── neorg
│   ├── events.lua
│   ├── external
│   │   ├── helpers.lua
│   │   └── log.lua
│   ├── modules
│   │   ├── base.lua
│   │   └── core
│   │       ├── autocommands
│   │       │   └── module.lua
│   │       └── keybinds
│   │           └── module.lua
│   └── modules.lua
└── neorg.lua
```

Above is a basic neorg file tree. 
Here's a quick rundown:
  - The `neorg/` directory holds all the logic
    - The `external/` directory is something you shouldn't worry about, as those are usually either 3rd party files or some small helper functions.
    - The `modules/` directory is where all the modules go. **Each module has its own subdirectory** - the contained `module.lua` file is the main file that gets sourced. Think of it as the init.lua for neorg modules.
      - `modules/base.lua` is the file that should get sourced in every module that is made. It contains the `neorg.modules.create()` function and has the default table that all modules inherit from.
    - `modules.lua` contains all the API functions for interacting with and querying data from loaded modules.
    - `events.lua` contains all the API functions for defining and interacting with events.

# Introduction to Modules
### What is a module
In reality, modules are just a fancy and easy way to manage and load code. Modules can be loaded at will, meaning they're not active unless you explicitly load them - this means there's no unnecessary code running in the background slowing the entire editor down. Whenever a module is loaded, the `setup()` function is invoked. We'll talk more about what the functions do later. Whenever an event is received, the `on_event(event)` function is called. Do you get the idea? Modules have several inbuilt functions that allow you to react to several different situations inside the neorg environment. They also allow you, the creator of the module, to expose your own public functions and variables to allow other modules to easily interact with you. You can also expose your own custom `config` table, which allows the user to potentially override anything they may please. To sum it up, **there's a lot you can do to finely control what happens and how much you want to expose about yourself**.

### Addressing modules
In neorg, there's two types of addressing modes, relative and absolute. Despite these fairly scary names, the concept is quite simple.

Let's say I want to reference the module in `neorg/modules/core/autocommands` (see [Understanding the File Tree](#understanding-the-file-tree) if you haven't already). Addressing this in an absolute manner would look like this `core.autocommands`. Easy enough, right? Relative addressing is contextual and may differ depending on the function being called. Don't worry, if a function requires a relative address (for example `autocommands`), it will let you know in the function documentation. You shouldn't worry about it too much yet, because relative addressing is mostly prevalent when dealing with events. Just wanted to let you know that such a thing exists though :)

### Module Naming Conventions
Whenever you pick a name for a module, make sure that the name is unique. The best way to make a unique name is by calling the module e.g `file_management.filereader`, where the module has a category and a name. You can even make subcategories, like this: `file_management.reading.file_reader`. This would mean that the `module.lua` file would be located in `neorg/modules/file_management/reading/file_reader/module.lua`. All core neorg modules are part of the `core` category, for example `core.autocommands` and `core.keybinds`.

# Writing a Barebones Neorg Module

### The basics
In this section we will start building a barebones template for our module! Let's start with the important questions - what will we name our module? What will our module do? How will it fit in the neorg environment? These are the most important things you should keep in mind when developing neorg modules

Let's answer the questions one by one:
  - We'll call it `example.module` because honestly why not
  - Our module will print some messages whenever certain actions are triggered
  - It won't

... 
---

I'm just kidding. You thought we were gonna do something so boring? Caught you slacking, think harder this time.

***Let's answer the questions one by one:***
  - We'll call it `utilities.dateinserter`
  - Our module will allow the user to do some basic things like insert the current date and time into a buffer
  - We will expose a small public API to allow other modules to interface with us and remotely force a date to be pasted into a buffer. We will also allow querying of that time and date as a string.

#### There!
Not too crazy, but should be at least a bit more interesting than the stuff we would've been working with earlier.

### Setting up the module
In order to make the module readable by neorg, we have to place it in the correct directory.
If our module name is to be `utilities.dateinserter`, we need to create the directory `neorg/modules/utilities/dateinserter`.

Locate where your modules are loaded by neorg (you can probably find it in `stdpath('data') .. '/site'`), and enter the directory we specified above. For me the output of pwd is `~/.local/share/nvim/site/pack/packer/start/neorg/lua/modules/utilities/dateinserter`. Inside here let's create a `module.lua` file, this is the file that will get sourced by neorg automatically upon load.

Here's some example contents, let's go over the file bit by bit:

```lua
--[[
    DATEINSERTER
    This module is responsible for handling the insertion of date and time into a neorg buffer.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("utilities.dateinserter")

return module
```

So... what is there to know about our current bit of code?

At top we provide an explanation about the module - this is important as it lets others know how to use the module and what the module actually does.

Next, we require `neorg.modules.base`, which is a file every module needs to include. It contains all the barebones and basic stuff you'll need to create a module for neorg.

Afterwards, we create a local variable `module` with the `neorg.modules.create()` function. This function takes in an **absolute** path to the module. Since our `module.lua` is in `modules/utilities/dateinserter/`, we *need* to pass `utilities.dateinserter` into the create() function. Not doing so will cause a lot of unintended side effects, so try not to lie to a machine, will you now.

### Adding functionality through neorg callbacks
The return value of `neorg.modules.create()` is an implementation of a fully fledged neorg module. Let's look at the functions provided to us by neorg and then they are invoked:
  - `module.setup()` -> the first ever function to be called. The goal of this function is to do some very early setup and to return some basic metadata about our plugin for neorg to parse.
  - `module.load()` -> gets invoked after all dependencies for the module are loaded and after everything is set up and stable - here you can do the serious initialization.
  - `module.on_event(event)` -> triggered whenever an `event` is broadcasted to the module. Events will be talked about more later on.
  - `module.unload()` -> gets invoked whenever the module is unloaded, you can do your cleanup here.
 
So let's add all the barebones!

```lua
--[[
    DATEINSERTER
    This module is responsible for handling the insertion of date and time into a neorg buffer.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("utilities.dateinserter")
local log = require('neorg.external.log')

module.load = function()
  log.info("DATEINSERTER loaded!")
end

module.public = {

  version = "0.1",

  insert_datetime = function()
    vim.cmd("put =strftime('%c')")
  end

}

return module
```

Woah, we added quite the bit of stuff now, what's going on?

Let's start with the easiest things first:
  - The logger - here we require `neorg.external.log`, which gives us a global instance of the logger. Note that the logger is a slightly modified version of [vlog.nvim](https://github.com/tjdevries/vlog.nvim), and you can find the docs there.
  - The `public` table, what is it?
    - The `public` table is what allows you to expose your own custom functionality to other modules that are loaded - you can put anything in this table, functions, variables, whatever. Note that it's good practice to expose a `module.public.version` variable with the current version stored as a string.
    - We add the `insert_datetime` function that will be able to be called from anywhere in the neorg environment, pretty neat!

# Events - an Introduction
Events are a way for different modules to communicate - they can hold several bits of data that may be useful for the recipient.

Theory:
  - The recipient and referrer - a recipient is the module that receives the actual event, whilst the referrer is the module that sent the event.
  - The root module and root categories - events are defined within your own module inside the `module.events.defined` table. The root module is the one in which this definition is contained. Logically, this means that the root categories are the categories in which the root module is.
  - Absolute naming conventions - each event has something officially referred to as the `type`, but you can also just call it the name of the event. Whenever you receive an event through `module.on_event(event)`, the value of `event.type` will be `<root_categories>.<root_module_name>.events.<event_categories>.<event_type>`. This may seem a tad confusing now, but will make sense as we go on.
  - Event definitions - whenever you create an event, you get a choice. You can either derive from the **base event**, which provides all the default tables, or you can build atop the base event and add your own features. Building on top of the default event is by nature what a `definition` is. When the event is referenced, however, it is then referred to as an **event template** in the code, as you use that definition as a template to create **instances** of that event to send to other modules. Geez, what a mouthful.
  - Event broadcasting and event sending - whenever you send an event, you are doing exactly that, only *sending* the event to a single module. No other modules will receive the event. Whenever you broadcast, however, you asynchronously notify *all* subscribed and loaded modules in the neorg environment.

# Defining and Broadcasting our Own Event!
Time to define our own event! Let's add some code.

```lua
--[[
    DATEINSERTER
    This module is responsible for handling the insertion of date and time into a neorg buffer.
--]]

require('neorg.modules.base')
require('neorg.events')

local module = neorg.modules.create("utilities.dateinserter")
local log = require('neorg.external.log')

module.load = function()
  log.info("DATEINSERTER loaded!")
  neorg.events.broadcast_event(module, neorg.events.create(module, "utilities.dateinserter.events.our_event"))
end

module.on_event = function(event)
  log.info("Received event:", event)
end

module.public = {

  version = "0.1",

  insert_datetime = function()
    vim.cmd("put =strftime('%c')")
  end

}

module.events.defined = {

  our_event = neorg.events.define(module, "our_event")

}

module.events.subscribed = {

  ["utilities.dateinserter"] = {
    our_event = true
  }

}

return module
```

### Explanation time!
What have we added in the above code snippet? Well, first of all, we added a new require statement! Since we're going to be dealing with events now, we'll `require('neorg.events')`. This contains all the important functions regarding creating, broadcasting, manipulating events.

We added a new inbuilt function - `module.on_event()`; this function is invoked whenever we receive an event. It just simply logs the event that we received upon receiving it.

Inside the `module.load()` function we broadcast a new event using the `neorg.events.broadcast_event()` function! It takes in the current module that is invoking the function and an **instance** of an event template. We can create such an instance using `neorg.events.create()`. Note that `neorg.events.create()` takes an **absolute** path to the event, that's why we use `utilities.dateinserter.events.our_event` as a parameter.

Inside `module.events.defined` we define our first event! We call it `our_event` and set it to `neorg.events.define(module, "our_event")` where `module` is the module that's invoking the function (that's us!) and `"our_event"` is the **relative address** for the event. This is our first time encountering such an addressing mode - can you start to get an idea of how they work now? Since we are already in the context of our module (`utilities.dateinserter`), we don't need the full path to define an event, since only we can define our own events. Neorg knows this and can infer the rest by itself.

After defining the event and showing neorg it exists we now need to subscribe to it. Just defining an event isn't enough, we want to be able to finely control which events come our way. For this we use the `module.events.subscribed` table. We first create a subtable called `utilities.datainserter` - hey, that's the name of our module! The way you subscribe to events is with groups, since a module will usually have more than one event you'd like to subscribe to having to rewrite "utilities.dateinserter" for every single event it exposes would be rather painful. That's why we first define a group (our module name) and then subscribe to its events. Note that `our_event = true` is once again using relative addressing, since we're already in the "utilities.dateinserter" group the absolute path can be inferred. Whenever an event gets set to false (so e.g. if we wrote `our_event = false`) it is the equivalent of unsubscribing from the event.

### Let's test!
It's time to test whether it works but... it doesn't work. Why? What are the prerequisites? Hehe, glad you asked. Your module can't just be loaded, how bad would it be if all available modules got loaded each time? The user needs to pick n choose which modules they want, which is exactly what we're going to do now.
This part assumes you're using [packer.nvim](https://github.com/wbthomason/packer.nvim), although you should be able to easily follow along with any other package manager.

Let's take a look at how we set up neorg. If you've seen the code in the README, you should already have a rough idea of what's going on.

```lua

use { 'Vhyrro/neorg', config = function()

  require('neorg').setup {
      load = {
        ...
      }
  }

end}

```

We're going to modify this to suit our needs, then we will explain what's happening.

```lua

use { 'Vhyrro/neorg', config = function()

    require('neorg').setup {
       load = {
         ["utilities.dateinserter"] = {}
       },
    
       logger = {
         use_console = true
       }
    }
    
end}

```

Here in the `setup` function we configure the modules we would like to load. We do this by setting `["utilities.dateinserter"]` to an empty table. Certain info can be put into this empty table, but we will worry about that later.

Further down we change the settings for the neorg logger. By default logging to the console is disabled, but since we're creating our own test plugin and logging certain things we definitely want this to be set to `true` for our convenience.

### We should be good to go now!
To trigger neorg and therefore all the modules defined in the `load` table we need to either enter a `.org` file or a `.norg` file. Entering either one of such files should trigger everything, and you should see the event in the messages down below! To view all of it, type `:messages` into the command bar.
You should see that events hold a lot of data by default! This is stuff I believed to be important and things I would want to know whenever I receive an event.
Try to get yourself familiar with all of the elements of the table, as they are pretty important and useful!

Let's go over all those elements one by one and explain them for you:
```lua
event = {
	type = "core.base_event",
	split_type = {},
	content = nil,
	referrer = nil,
	broadcast = true,

	cursor_position = {},
	filename = "",
	filehead = "",
	line_content = ""
}
```

What you see above are both all the default elements that come with every event but also their default values. So, let's begin:
  - `type` - the absolute path to the event (e.g. `utilities.dateinserter.events.our_event`)
  - `split_type` - the absolute path to the event except split into two! The split point is at `.events.`, meaning in our case this would be equal to `{ "utilities.dateinserter", "our_event" }`
  - `content` - an optional string or table, this holds some optional content to send additionally alongside what we already currently have! You can pass some content through the `neorg.events.create()` function, like so: `neorg.events.create(module, "utilities.dateinserter.events.our_event", { my_content_here = "pretty cool!" })` or `neorg.events.create(module, "utilities.dateinserter.events.our_event", "this is some content!")`
  - `referrer` - see [the theory behind events](#events---an-introduction). This is the name of the module that actually broadcasts or sends the event.
  - `broadcast` - if the event was broadcasted via `neorg.events.broadcast_event()` then this is `true`, otherwise `false`
  - `cursor_position` - the cursor position as returned by `vim.api.nvim_win_get_cursor(0)`
  - `filename` - the filename as returned by `expand("%:t")`
  - `filehead` - the directory leading up to the file as returned by `expand("%:p:h")`
  - `line_content` - the content of the current line the user was on at the time of triggering the event

### I wanna be more private
Let's say we don't really want the entire world to know that we have just broadcasted an event. What then? Instead of using `neorg.events.broadcast_event()`, we can just use `neorg.events.send_event(module, recipient, event)`. As you can see, it takes an extra argument in the middle which is the recipient - the target module we want to notify. Let's change up our code again to use `send_event` now:

```lua
--[[
    DATEINSERTER
    This module is responsible for handling the insertion of date and time into a neorg buffer.
--]]

require('neorg.modules.base')
require('neorg.events')

local module = neorg.modules.create("utilities.dateinserter")
local log = require('neorg.external.log')

module.load = function()
  log.info("DATEINSERTER loaded!")
  neorg.events.send_event(module, "utilities.dateinserter", neorg.events.create(module, "utilities.dateinserter.events.our_event"))
end

module.on_event = function(event)
  log.info("Received event:", event)
end

module.public = {

  version = "0.2",

  insert_datetime = function()
    vim.cmd("put =strftime('%c')")
  end

}

module.events.defined = {

  our_event = neorg.events.define(module, "our_event")

}

module.events.subscribed = {

  ["utilities.dateinserter"] = {
    our_event = true
  }

}

return module
```

If you now save the file and enter a new `.org` or `.norg` file, you should see that nothing has changed. That's good! It means that the event is being delivered to your module and your module *only*. No other module will be able to see it.

# Configuration
Every bit of software needs to be configurable, right? Thankfully neorg allows for exactly that - you can expose your own options to be configurable.
We'll do something pretty basic, but it'll still give you an idea of how it works.

### Adding some code
Just before the `return module` statement in your code add this:

```lua
module.config = {

	private = {},
	
	public = {
		enabled = true
	}

}
```

We just added a new table to our module - it's called `config`. Inside of this table we will always have **2** subtables - private and public. Whatever you put in private is yours and yours only. It can be used for internal debug options or whatever you don't want the user to dabble with. Whatever you put in public, on the other hand, can be modified by the user at will; it's also exposed to any module wanting to change your behaviour. We expose a simple variable called `enabled`, which will allow the user to toggle the module on and off - kinda useless, but it's nice for a learning experience.

### How do we change it?
If you're a module wanting to query the configuration for a module, you can use the `neorg.modules.get_module_config(module_name)`. It will return `nil` if the module cannot be found, but will return the whole public config table otherwise.
If you're a regular user, however, you can just change this code:

```lua
use { 'Vhyrro/neorg', config = function()

    require('neorg').setup {
       load = {
         ["utilities.dateinserter"] = {}
       },
    
       logger = {
         use_console = true
       }
    }
    
end}
```

Into this:

```lua
use { 'Vhyrro/neorg', config = function()

    require('neorg').setup {
       load = {
         ["utilities.dateinserter"] = { 
	 	config = { 
			enabled = false
		}
	 }
       },
    
       logger = {
         use_console = true
       }
    }
    
end}
```

Do you see what we did there? We can configure any module just like that: by using the `config` table.

### Making the module react on these changes
Let's change this snippet of code:

```lua

module.on_event = function()
	log.info("Received event:", event)
end

```

And add an `if` check:

```lua

module.on_event = function(event)
	if module.config.public.enabled then
		log.info("Received event:", event)
	end
end

```

That's it! Let's see whether the changes will take effect. If using packer, make sure to `:PackerCompile` before testing! You should see that on entering any norg file nothing happens. It's cause the user overrode our config options! That's how you expose configuration.

# Basics figured out
Alright! Well done! You've got the basics out of the way, but it's not over yet. We still have some more things to cover, so hold out just a little longer. If it's hard to read so much text for you, imagine how I must've felt writing it, lol.

---

# Inbuilt Modules
## core.autocommands
Ever wanted to bind an event to an autocommand? Well, maybe it crossed your mind, but I wouldn't imagine it being a dream of yours or something. Anyway, we can do that with neorg's own `core.autocommands` module.

How do we do it? It's quite simple, really. But before we do so, we need to understand one more concept - **requiring**. It's as easy as it sounds, we can require other modules to be loaded before ours is! Very nice. Let's see it in action. If you've read [the introduction to modules](#introduction-to-modules), you should recall the `setup()` function, right? It allows you to do some special preinitialization and allows you to return some simple metadata to neorg. Well it just so happens that part of that metadata is what modules we require, so let's begin!

```lua

local module = neorg.modules.create("utilities.dateinserter")

...

module.setup = function()
	return { success = true, requires = { "core.autocommands" } }
end

```

Add the setup function wherever you please in your code, and let's start explaining the return value of `setup()`:
	- `success` - as the name suggests, it tells neorg whether or not the plugin has successfully loaded. If `false` then neorg will halt the loading of that module.
	- `requires` - an array of absolute paths to modules that we want to load beforehand. If a module has already been loaded, it will just be ignored.

Now we can be certain that whenever our module is loaded, `core.autocommands` will be alongside it.

### The side effect of requiring a module
Whenever you require a module, it probably means you want to use its functionality, right? Well we got you covered. Whenever you require a module, its `public` table will be available at `module.required["core.autocommands"]`. Yeah. Whatever you change there will also impact that table.

So let's try binding ourselves to an autocommand! For this example only, we'll rewrite our module to something smaller and easier to comprehend:

```lua

--[[
    DATEINSERTER
    This module is responsible for handling the insertion of date and time into a neorg buffer.
--]]

require('neorg.modules.base')
require('neorg.events')

local module = neorg.modules.create("utilities.dateinserter")
local log = require('neorg.external.log')

module.setup = function()
	return { success = true, requires = { "core.autocommands" } }
end

module.on_event = function(event)
	if event.type == "core.autocommands.events.insertenter" then
		(vim.schedule_wrap(function() module.public.insert_datetime() end))()
	end
end

module.load = function()
	module.required["core.autocommands"].enable_autocommand("insertenter")
end

module.public = {

  version = "0.3",

  insert_datetime = function()
    vim.cmd("put =strftime('%c')")
  end

}

module.events.subscribed = {

  ["core.autocommands"] = {
    insertenter = true
  }

}

return module

```

### Explanation
Here we've cut some unnecessary stuff out and left all the important stuff in. If you don't know how to use a module, check out its documentation which is found at the top of its `module.lua` file.
`core.autocommands` exposes a public function called `enable_autocommand()` - by default all autocommands are disabled for performance reasons and need to be enabled manually through this function. If an invalid autocommand is passed nothing happens.

After enabling the autocommand, we need to listen for it - we do so in the `module.events.subscribed` table. You should know the drill by now. Let's test! If you launch an norg file and enter insert mode you should get the current date and time pasted into your buffer!

## core.keybinds
It's time we bind some keys! Keybinds are one of the most important foundations of any plugin as they allow fine control without having to navigate menus to execute a command.
As always, official documentation for the module can be found here in the `USAGE:` block.
Here's our code for this section, then we'll explain it bit by bit:

```lua

--[[
    DATEINSERTER
    This module is responsible for handling the insertion of date and time into a neorg buffer.
--]]

require('neorg.modules.base')
require('neorg.events')

local module = neorg.modules.create("utilities.dateinserter")

module.setup = function()
	return { success = true, requires = { "core.keybinds" } }
end

module.on_event = function(event)
	if event.split_type[2] == "utilities.dateinserter.insert_datetime" then
		(vim.schedule_wrap(function() module.public.insert_datetime() end))()
	end
end

module.public = {

  version = "0.4",

  insert_datetime = function()
    vim.cmd("put =strftime('%c')")
  end

}

module.events.subscribed = {

  ["core.keybinds"] = {
    ["utilities.dateinserter.insert_datetime"] = true
  }

}

module.config.public = {

	keybinds = {

		["<Leader>oid"] = {
			name = "insert_datetime",
			mode = "n",
			opts = { silent = true }
		}

	}

}

return module

```

Well, let's give it everything we've got, it's explaining time!

First, we require the `core.keybinds` module in the `setup()` function, then we subscribe to the event. You'll notice some quirkiness here though, because we have an absolute path inside a place where there should be a relative path! What's going on? Well, whenever you bind a key, it needs to be bound to *your* module specifically. To do this, `core.keybinds` utilizes the event system to store your module name as well. So, whenever you receive an event, it will look like this (for example): `core.keybinds.events.utilities.dateinserter.<your keybind name>`, where `<your keybind name>` is the value of `["<Leader>oid"].name` (in this case). Whew, what a mouthful.

Just gonna go off on a small tangent here, but I wanted to let you know that `core.keybinds` uses an inbuilt function called `neorg_post_load()`. What is that, you may ask? It's a function that gets invoked after *all* modules have been initialized and loaded, you can define it yourself, like so: `module.neorg_post_load = function() ...`. 

`core.keybinds` uses this to read every single loaded module's `module.config.public.keybinds` table, and uses the things defined there to create keybinds! That's why it all happens automagically without you having to do something like `module.required["core.keybinds"].add_keybind(...)`. *END OF SMALL TANGENT*

Inside the `module.config.public.keybinds` we define keymaps. The formula looks like so:

```lua

["keybind_here"] = {

	name = "some_name", 	-- The name of the keybind. Make it descriptive
	mode = "n", 		-- Which mode the keybind should run in, can be 'n', 'v', 'i' etc.
	opts = {} 		-- Options to pass into vim.api.nvim_set_keymap
}

```

If you look at the `on_event()` function, you can see we're using some magic function called `vim.schedule_wrap`. What's that? If you don't know, it just delays the execution of that function until it is safe for neovim to call. Doing it without this function will result in an error, as `on_event()` calls happen asynchronously.

# Pushing our Modules to Git and Pulling them from There
As of right now, neorg has the foundation ready, but the *actual* code that pulls from github is not implemented yet, stay tuned for that! The documentation will become bigger as features become readily available.

---

# THE END
Congratulations! If you are still alive while reading this, then you made it! You should have enough basic knowledge to now extend and bend neorg to your will. For *all* available module tables and function alongside explanations, see [the base file](/lua/neorg/modules/base.lua).

Thank you so much for reading! :heart:
