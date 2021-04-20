<div align="center">

# Creating Modules for Neorg
The magic behind the scenes, or in other words understanding the inner workings of neorg.

</div>

---

Table of Contents:
  - Understanding the file tree
  - Introduction to modules
  - Writing a barebones neorg module
  - Introduction to events
  - Broadcasting an event
  - Inbuilt modules:
    - The core.autocommands module
    - The core.keybinds module
  - Publishing our module to github and downloading it from there

---

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

... I'm just kidding. You thought we were gonna do something so boring? Caught you slacking, think harder this time.

**Let's answer the questions one by one:**
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

  insert_datetime = function()
    vim.cmd("put =strftime(\"%c\")") 
  end

}

return module
```
