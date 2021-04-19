<div align="center">

# Neorg - An Organized Future

![License](https://img.shields.io/badge/license-GPL%20v3-brightgreen?style=flat-square)
![Status](https://img.shields.io/badge/status-WIP-informational?style=flat-square)
![Requires](https://img.shields.io/badge/requires-neovim%200.5%2B-green?style=flat-square)

</div>

---

> The pain... it won't stop. After so much oppression from other text editors, it's time we fight back.
With the introduction of lua, we *will* fight back.

---

### Table of Contents
- [Introduction](#introduction)
- [Installation](#installation)
- [WIP Status](#wip)
- [Check out the wiki](#consult-the-wiki)
- [Contributing](#contributing)

# Introduction
### What this project is, and what it isn't
  - This project is supposed to serve as an organizational tool for Neovim. It will run on the .norg file format - a revised, extensible and more computer friendly format compared to .org, all while retaining a decent amount of backwards compatibility with org (you will be able to convert between both formats).
  - A foundation for developers to make their own extensions to the plugin and interface with other parts of user-contibuted code, known as modules (mode info below)
  - A full on competitor to emacs's org-mode
 ### What this project isn't
  - **An org-mode clone** - this project does not plan on recreating or cloning org mode in neovim. Rather, the goal of this repo is to take concepts from other organizational tools and reimagine them for the great text editor that neovim is. Expect a bit of familiarity but also a lot of changes, things tailored to the vim philosophy.

---
# Installation
## Using packer
To install using packer:
```lua
  use { 'Vhyrro/neorg', config = function()
      require('neorg').setup {
        load = {
          ["your.module"] = { git_address = 'some/address', config = { ... } }
        }
      }
  end}
```

If you're feeling lucky and want all the bleeding edge features (might require Neovim HEAD):
```lua

  use { 'Vhyrro/neorg', branch = 'unstable', config = function()
      require('neorg').setup {
        load = {
          ["your.module"] = { git_address = 'some/address', config = { ... } }
        }
      }
  end}
```

Then run `:PackerSync`

# WIP
As can be seen, this plugin is a work in progress - these magical features don't come out of nowhere, you know. Despite not providing any end-user features *yet*, it does provide an incredible foundation for developers willing to spend some time writing code for the plugin:
  - The module system; the module system is an extensible way to manage and interface with code. Modules are pay-for-what-you-use tables that can get loaded and unloaded at will. They can subscribe to events using the powerful event system and can directly communicate with each other - they can even expose their own public APIs and configuration to be edited by the user. Example modules can be found [here](lua/neorg/modules/core) and in the wiki.
  - The event system; the event system is the way for said modules to communicate. Events can be broadcast to all subscribed modules or to individual modules as well, they can hold any sort of data you'd want to transport to another plugin, things like the current cursor position, line content etc. The choice is yours really.

# Consult The Wiki!
The entire structure of neorg's core can be a bit complex, so it's definitely worth your time to read the docs! For now you can take a look at them [here](docs/README.md), but in the future the actual github wiki will be available.

# Contributing
I really looove contributions! That's what this whole project is about - it's a really big plugin, so any help is appreciated :heart:
