<div align="center">

# The Neorg Roadmap
What's going on behind the scenes? What has been done? Where are we heading next? It's all described here.

</div>

Table of Contents:
- [x] [Beginning PR stuff](#pr-stuff) (**DONE** 2021-04-27)
- [ ] [Road to 0.1 release](#road-to-01-release)
- [ ] [What we are planning to do after 0.1](#plans-after-01)

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
- [x] Start work on a basic "specification" for the .norg file format. The name of this file format will be NFF-0.1 (Neorg File Format 0.1). The community will be asked about what they think before the specification is pushed (join the [discord](https://discord.gg/T6EgTAX7ht) if you haven't already). (**DONE** 2021-05-12)
- [x] Add custom modes to neorg - take neovim's modal design and take it to its limit. Modes will be primarily used to isolate keybindings from each other, but will also allow modules to perform different tasks based on the mode.
- [x] Implement metamodules. These modules will be an easy way to `require` a large batch of modules without the user having to specify each individual module they prefer. For example, a `default` metamodule may exist in order to include all the basic modules that neorg has to efficiently edit norg files. (**DONE** 2021-05-04)
- [x] Implement a `core.norg.concealer` module - this module will make the experience much more aesthetically pleasing by using icons for bits of text rather than raw text itself (**DONE** 2021-05-28).
- [x] Allow todo items to be checked, unchecked and marked as pending with a keybind. (**DONE** 2021-05-29)
- [x] Extend functionality of metamodules, allow individual modules from a metamodule to be selectively disabled (**DONE** 2021-05-30).
- [x] Module to manage directories where .norg files can be stored (`core.norg.dirman`).
- [x] Make fancy README
- [x] Create the .norg spec. This spec will try to be similar to other markdown formats, but does not promise to keep everything the same. The goal is as little ambiguity and as much predictability as possible.
- [ ] Telescope.nvim plugin to interact with `core.norg.dirman` and fuzzy find .norg files etc.
- [x] Implement a Treesitter parser
	- [x] Syntax highlight
	- [ ] Indentation engine
- [ ] Create an nvim-compe completion source

### Things that might be done in this release:
- [x] Asynchronous module loading - on the surface this seems very trivial, but I have encountered a problem I cannot find a solution to online. The module loader uses pcall() to require the modules (in case they don't exist), but the problem is pcall just does not work asynchronously, no matter what I tried. Until a fix isn't found for this, async module loading will not be a possibility. I might be just dumb though in which case let me know how to fix it :) (**DONE** 2021-05-03 | Migrated over to plenary.nvim, all works awesome now)
- [x] Add more API functions. These functions will just allow any module to more easily interact with the environment around them; some quality-of-life stuff.
- [ ] Add a module for efficiently managing and manipulating vim windows, be it splits, floating windows etc.

# Plans after 0.1
> Ok that's pretty cool, so after 0.1 I should be at least able to do some basic stuff, right? What's next though?

First of all, yeah, after 0.1 all the main boring stuff should be out of the way. Sooo what's next? Currently there is no real plan, but here are some things we might want to do:
- Add the concept of notes and note management. Each note will be its own .norg file. Also add a personal diary to store notes on a day-by-day basis and "quick notes", where you can press a keybind and quickly jot down a nice idea you might have had; you'll be able to sort through it later.
- Add more literate programming features
- Make more things bound to a keybind, this is neovim damnit. Most keybinds will be bound under `<Leader>o` for "organization" by default (this main neorg leader will be able to be changed).
- Add more features to the `:Neorg` command, like a fully-fledged module manager inside a floating window
- Add the ability to upgrade .org documents and downgrade .norg documents to their respective formats.
- Add fancy UI elements for the true user experience
