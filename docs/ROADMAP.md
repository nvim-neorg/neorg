<div align="center">

# The Neorg Roadmap
What's going on behind the scenes? What has been done? Where are we heading next? It's all described here.

</div>

Table of Contents:
- [x] [Beginning PR stuff](#pr-stuff) (**DONE** 2021-04-27)
- [ ] [Road to 0.1 release](#road-to-01-release)
- [ ] [What we are planning to do after 0.1](#plans-after-01)

Extra info:
- [The neorg file format](#the-nff)

---

# PR Stuff
For starters, I have to set everything up in order to make the project comprehensible by the everyday user. This will include writing this very roadmap and writing the github wiki.

The github wiki will consist of:
- [x] Detailed instructions to install and configure neorg
- [x] Documentation for pulling modules from github/interacting with modules
- [x] Documentation for existing core modules

More will be added to this wiki as neorg grows larger and larger.

# Road to 0.1 Release
After the PR things are out of the way, the development of Neorg 0.1 will commence.

The 0.1 release will be the equivalent of the MVP (Minimal Viable Product). This release will be the one where neorg is stable enough to be used in extreme situations and to perform basic neorg tasks like adding headings and maybe tangling.
Here is where you will see the initial introduction of the .norg file format.

Things to be done in this release:
- [x] Implement a new feature for the return value of the `module.setup()` function - `replaces`. Example usage:
	```lua
		module.setup = function()
			return { success = true, replaces = "core.neorgcmd" }
		end
	```
	This will tell neorg to *replace* the core.neorgcmd module with this one. Should be obviously used with caution, but may prove very useful in the future for hotswapping modules with a small tradeoff in terms of stability.
	Have no clue what the above code snippet does and want to learn? Read the [CREATING_MODULES.md document](https://github.com/vhyrro/neorg/wiki/Creating-Modules).

	**DONE** (2021-04-28) - note that this addition may be unstable, and will be kept in the unstable branch for the time being.
- [x] Fix a bug in `core.keybinds`, where it's currently impossible to bind a certain event to a *new* keybind. (**DONE** 2021-04-29)
- [x] Allow the default `<Leader>o` keybind to be remapped and allow the user to add a special flag in order to automatically prefix their keybind with it. (**DONE** 2021-04-31)
- [x] Create a `core.neorgcmd` module. This module will allow the use of the `:Neorg` command and will allow other modules to define their own custom functions to be executed in this command, e.g. `:Neorg my_custom_command`. Default commands will be `:Neorg list modules` (VERY BASIC, will be remastered soon) to list currently loaded modules. More will be added in the future. (**DONE** 2021-05-02)
- [x] Create the wiki/docs for `core.neorgcmd` (**DONE** 2021-05-03)
- [x] Allow the installation of modules from github using `:Neorg install some/address` (**DONE** 2021-05-08)
- [x] Allow all community modules to be updated with `:Neorg update modules` (**DONE** 2021-05-12)
- [x] Allow the user to change the community module directory (**DONE** 2021-05-10)
- [x] Start work on a basic specification for the .norg file format. The name of this file format will be NFF-0.1 (Neorg File Format 0.1). The community will be asked about what they think before the specification is pushed (join the [discord](https://discord.gg/T6EgTAX7ht) if you haven't already). (**DONE** 2021-05-12)
- [x] Add custom modes to neorg - take neovim's modal design and take it to its limit. Modes will be primarily used to isolate keybindings from each other, but will also allow modules to perform different tasks based on the mode.
- [x] Begin implementing the norg parser module. This will be the most complex module out of all the ones that will exist in neorg, so this one will take a while. The norg parser will generate a syntax tree from the current norg file. Other modules will be able to interface with this syntax tree, and the corresponding buffer will update accordingly (both the syntax tree and the actual buffer will be in sync). This is where the heart of neorg will reside, which is why the most effort needs to be put into it in order to make it truly extensible.
	- [x] Start work on the scanner (**DONE** - the scanner is complete, however currently it is only that - a scanner. It needs to be rewritten and instead implemented as a lexer for greater flexibility.)
	- [ ] Create the parser - the parser takes inputs from the lexer and converts it into an abstract syntax tree.
- [x] Implement metamodules. These modules will be an easy way to `require` a large batch of modules without the user having to specify each individual module they prefer. For example, a `default` metamodule may exist in order to include all the basic modules that neorg has to efficiently edit norg files. (**DONE** 2021-05-04)
- [ ] Add more API functions. These functions will just allow any module to more easily interact with the environment around them; some quality-of-life stuff.
- [ ] After all the core stuff is out of the way, the first module to actually do organizational stuff will be born - enter `core.org.headings`. This module will handle headings and subheadings, and will work together with the `core.norg` parser to provide extra functionality. Things it will be able to do are inserting and deleting headings, changing the indentation level of a heading, having fancy icons and colours and having keybinds to make the experience more vim-like and streamlined.

Things that might be done in this release:
- [x] Asynchronous module loading - on the surface this seems very trivial, but I have encountered a problem I cannot find a solution to online. The module loader uses pcall() to require the modules (in case they don't exist), but the problem is pcall just does not work asynchronously, no matter what I tried. Until a fix isn't found for this, async module loading will not be a possibility. I might be just dumb though in which case let me know how to fix it :) (**DONE** 2021-05-03 | Migrated over to plenary.nvim, all works awesome now)
- [ ] Automatic grabbing from GitHub - if a module cannot be found when the `neorg.modules.load...()` family of functions are invoked then asynchronously grab it from GitHub then try again. This one has proven to be a bit difficult for me, as I do not have much experience with async lua yet. This feat could probably be achieved with coroutines, but I am not certain. If you do know, contact me!
- [ ] Tangling. This feature will allow you to write your own configs in neorg, which would be a massive flex.
- [ ] Add a module for efficiently managing and manipulating vim windows, be it splits, floating windows etc.

# Plans after 0.1
> Ok that's pretty cool, so after 0.1 I should be at least able to do some basic stuff, right? What's next though?

First of all, yeah, after 0.1 all the main boring stuff should be out of the way. Sooo what's next? Currently there is no real plan, but here are some things we might want to do:
- Add the concept of notes and note management. Each note will be its own .norg file. Also add a personal diary to store notes on a day-by-day basis and "quick notes", where you can press a keybind and quickly jot down a nice idea you might have had; you'll be able to sort through it later.
- Add more literate programming features
- Make more things bound to a keybind, this is neovim damnit. Most keybinds will be bound under `<Leader>o` for "organization" by default (this main neorg leader will be able to be changed).
- Add more features to the `:Neorg` command, like a fully-fledged module manager inside a floating window
- Add the ability to upgrade .org documents and downgrade .norg documents to their respective formats.

---
# The NFF
### What is the Neorg File Format - why not just use the .org format?
The Neorg File Format (`.norg`) is supposed to be a revised and more extensible alternative to the .org file format. The reason we don't use org is because their version of markdown is difficult to parse efficiently by a machine. Creating more efficient solutions in order to make neorg faster sounds like a good idea, don't you think? The .norg file format will not only be faster but also easier to customize and to build upon; it will be different under the hood, but we will try to make it a familiar experience. Expect all the basic markdown stuff to be practically the same, expect org-mode specific features to look different though.

### I have a bunch of org documents, what about those?
Don't worry, neorg will be able to convert between the two formats statically in the future. This means that neorg *won't* support org files in of themselves, but will allow you to convert them to .norg and *then* work on them. If you so please you will then be able to downgrade from .norg to org if you need the doc to be rendered automatically in GitHub or something.

### How long will I have to wait until the NFF is on par with org?
Well, that's really hard to say - the .org file format is a big beast, and this project was born very recently in terms of big projects. I can say for sure that I will work hard to give you all the features I can alongside the community, but I cannot provide a real date.
