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
