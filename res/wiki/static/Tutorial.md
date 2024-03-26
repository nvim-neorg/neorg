<div align="center">

# Getting Started

A guide on getting started with Neorg.

</div>

This file will get you started with Neorg as your general note taking and life management tool.

## Neorg as a Concept

First of all, welcome! There's quite a journey ahead of you, hope you stick around :)

Before we get into any of the details, let us discuss what Neorg *is* and what it *isn't*. Neorg is a frontend for a markup format called norg - it provides a load
of functions for interacting with these norg files. Think of Norg files as highly advanced Markdown files (if you've ever had experience with Markdown before).

The beauty of markup is that it can contain *anything* - general documentation for your project, notes about a school subject,
technical documentation for software, theses, presentation slides... you get the idea. Because plain text is so vertasile, Neorg is built to account for as many
use cases as possible.

If you haven't encountered this type of tool before, it's officially called an *organizational tool*. The name is vague because, well, the concept is pretty vague!
Neorg is a tool that can handle any task you throw at it, as long as you can represent that problem in plaintext.

Because of this, you'll never learn *all* of Neorg, and that's okay! As you get more comfortable in a certain part of Neorg (e.g. the note-taking side or the
task management side) you can then extend your knowledge to other domains if you need.

## Our First Steps

**The first thing you'll want to do is set up Neorg**. There's an entire guide present [here](#)! Feel free to check it out and - once you're done - hop back into this file
and get going.

Neorg is generally always active whenever you start Neovim (unless you lazy load it) - this allows you to jump to convenient locations and files whenever you need.

Before we get ahead of ourselves, let's get a feel for the default state of the plugin. By default, Neorg is merely an advanced editing tool. To see why and how, open up
any directory of your choice and open up a `note.norg` file. Ready?

## Basic Syntax

Norg has a lot of default syntax that should immediately feel familiar if you've use `org-mode` or some Markdown. First, let's type some text:

```norg
This is my note!
```

Just like in a basic `.txt` file or like in Markdown, any text is allowed within the document.
The power of markup languages shines in the ways you can alter the text though, so let's learn some!

#### Inline Markup

Any word can be made bold, italic, underline, superscript, subscript - all through the use of modifiers. Below are a bunch of examples:

```norg
This is just my note! In here I will have some *bold* text, some /italic/, _underline_, ^superscript^ and ,subscript,!
```

And indeed, upon typing those, you should see Neorg appropriately make the text **bold**, *italic* and __underline__! Superscript and subscript cannot be properly rendered
within terminals, so they're just coloured instead.

If the bold, italic or underline are not showing properly you can find a troubleshooting guide [here](https://github.com/nvim-neorg/neorg/wiki/Dependencies)! Terminals can be tricky sometimes :p

*Fantastic!* Being able to mark up any text like this without any effort is very nice.

#### Lists

As you're writing, you'll naturally want to enumerate some things in the form of a list. Below is a simple example of a list:

```norg
Below I'll create a list of things that I should buy:
- Apples
- Oranges
- Milk
```

All it takes is to prefix a line with a `- ` and you're set! Adding more than one new line will break the list apart into two:

```norg
Below I'll create two lists of things that I should buy:
- Apples
- Oranges

- Milk
```

Apart from unordered lists, you may want to enforce an order on the list. You may be inclined to do something like this:

```norg
Below I'll create an ordered list of stuff:

1. First thing
2. Second thing
```

Nobody's stopping you from doing this, but Neorg won't recognize the list, it'll just think it's text. In norg, ordered lists are defined using the tilde (`~`):

```norg
~ First thing
~ Second thing
```

If you have the [concealer](https://github.com/nvim-neorg/neorg/wiki/Concealer) module enabled this will automatically get visually converted into a numeric list.

This approach may seem very odd initially until it clicks. When you write lists using the `1.` syntax, any time you want to add an item or reorder the list, you have to manually update *all* of the
items afterwards, or keep track of what the index of the previous item was. Let's say I have a list of 10 items, and I want to move the second item to the end. Now I have to change the numbers of all
the other entries! What if I want to add a new item at the end of the list? You have to look through the list to see what the number of the last entry was so that you can increment it by one.

Using the `~` syntax, Neorg does all of the counting for you, while still displaying the appropriate list index through the concealer. Neat!
