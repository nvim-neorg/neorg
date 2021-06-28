# The Neorg 0.1 Specification
~~Yes I know it's ironic to have this file in markdown.~~

This file details all of the rules, concepts and design choices that went into creating the first true
iteration of the Neorg File Format version 0.1. Note that this version is still not final and may undergo
some small changes.

### Table of Contents
- [Theory](#theory)
- [Design decisions](#design-decisions)
	- [Parsing order](#parsing-order)
	- [Attached Modifiers and Their Functions](#attached-modifiers-and-their-functions)
	- [Detached Modifiers and Their Functions](#detached-modifiers-and-their-functions)
	- [Trailing modifiers](#trailing-modifiers)
	- [Escaping special characters](#escaping-special-characters)
	- [Defining data](#defining-data)
		- [Tag parameters](#tag-parameters)
		- [Carryover tags](#carryover-tags)
			- [Quirks](#quirks)
	- [Single-line paragraphs](#single-line-paragraphs)
	- [Intersecting modifiers](#intersecting-modifiers)
	- [Lists](#lists)
	- [Nesting](#nesting)
	- [TODO Lists](#todo-lists)
	- [Links](#links)
		- [The first segment](#the-first-segment)
		- [The second segment](#the-second-segment)
	- [Markers](#markers)
	- [Drawers](#drawers)
- [Data tags](#data-tags)
	- [Unsupported tags](#unsupported-tags)

# Theory
There are a few concepts that must be grasped in order to flawlessly interpret the specification, they
will be defined here.
- Paragraphs - paragraphs are portions of the file that simply represent text. Paragraphs only terminate
whenever two consecutive newlines are encountered, or whenever a paragraph-breaking `detached modifier` is encountered on the next line, *or*
if the current paragraph was a single-line paragraph.
More information about modifiers and detached modifiers can be found below.
- Punctuation - punctuation is any character that controls the intonation, flow or meaning of a sentence. Additional
punctuation marks are those that represent e.g. currencies. Currently punctuation is defined as `?!:;,.<>()[]{}'"/#%&$£-`,
where each individual character denotes a valid punctuation mark. This list will grow with newer specifications.
- Modifiers - modifiers are characters or sequences of characters that change the way a segment of text **within a paragraph** is displayed.
This can be the `*` modifier, which makes some text bold, the `_` modifier, which makes text italic, and so on. Every modifier
must form a pair, where the first modifier `*in this text*` is the _opening modifier_, and the second (last) modifier is the
_closing modifier_. Modifiers that do not form a pair are called detached modifiers, and have a different set of rules. Here are
the rules for regular (attached) modifiers:
	- An opening modifier may only be preceded by whitespace or by a punctuation mark, and may be followed by another modifier or by
	  an alphanumeric character. An opening modifier cannot have whitespace after itself.
	- A closing modifier may only be preceded with an alphanumeric character or by a modifier and may only be followed by whitespace
	  or by a punctuation mark.
- Detached modifiers - detached modifiers, similarly to regular modifiers, are characters that modify the behaviour of Neorg. However,
  rather than changing the way text is displayed, they change the way text is interpreted. Detached modifiers do not consist of an opening and closing modifier, but only of one single character,
  hence the name "detached". Such a modifier can be the `*` modifier, signalling a heading, or the `-` modifier, signalling an unordered list.
  The rules for a detached modifier are as follows:
	- A detached modifier may exist at the very beginning of a line and may only be preceded by whitespace.
	  It must have whitespace or another modifier of any type afterwards.
- Trailing modifiers - trailing modifiers are those that exist at the end of a line, and impact how the next line should be interpreted. Trailing modifiers have a very
  few simple rules, and they are:
	- A trailing modifier may only exist at the end of a line, and may not have any characters after itself.
	- A trailing modifier may have either a punctuation mark or an alphanumeric character before itself but **not** whitespace.
  Currently there is only one trailing modifier, and it is `~`. Its meaning will be discussed later on.

### Examples:

Considering the above rules, we can say that for regular modifiers:
- `* Something cool *` - INVALID
- `*Something cool*` - VALID
- `* Something cool*` - INVALID
- `*_Something cool_*` - VALID
- `*_Something cool_ *` - INVALID
- `*Something cool` - INVALID, no closing modifier

As for detached modifier rules:
- `*A heading` - INVALID, must have whitespace or a modifier afterwards
- `** A heading` - VALID, the first detached modifier is followed by another detached modifier which is followed by whitespace
- `Some* interesting text` - INVALID, will not yield any special result and will be treated as a regular `*` character.
- `- A list` - VALID
- `	- A list` - VALID, has preceding whitespace and also whitespace afterwards, treated as an unordered list
- `A list-` - INVALID, will be treated as a regular `-` character

And, finally, regarding trailing modifier rules:
- `Some text~` - VALID, trailing modifier has an alphanumeric character before itself and is at the end of a line
- `Some text~ ` - INVALID, trailing modifier has an alphanumeric character before itself but it is not at the end of the line (has trailing whitespace)
- `Some text ~` - INVALID, trailing modifier does not an alphanumeric character **or** punctuation mark before itself
- `Some text,~` - VALID, trailing modifier has an alphanumeric character or punctuation mark before itself and is at the end of a line

### Different Rules for Different Modifiers
Whilst all modifiers must adhere to the rules presented above, some modifiers may only be valid if the above rules are fulfilled _and_
some extra conditions are met. There will be a few modifiers that don't adhere to the presented rules above and add extra constraints - note the keyword
here, **add**. Extra rules can be only that - "extra"; they cannot change any of the rules that are presented above, but only provide extra constraints.

# Design decisions
Neorg's design goals are simplistic in nature - simplify existing concepts from other formats and allow for easy extensibility - be deterministic,
do not allow any extra side effects and be as explicit as possible.
Rather than operating on the principles of markdown, where some things work except they sometimes don't and the rest is up to the
implementation, Neorg works on a single principle: Things either work fully or don't work at all. Think of it as being simply more strict
with the rules we impose without limiting creativity and freedom. I, personally, would much rather something not work than it work
only in certain situations and only with hacky layouts.
Because of this, every feature is carefully looked over and all possible changes that could be made to that feature are considered.
If the feature is very fundamental then little to no changes are made so people can quickly familiarize themselves with the format, however -
certain, more complex elements will be treated more harshly in terms of changes.
After a long term massive brain thinking session, the current concepts are proposed, alongside explanations as to why they are benefitial
changes:
### Parsing Order 
  The Neorg lexer should read every modifier from left to right in the most logical order possible.
  This means that `*This bit* of text*` should be interpreted as "**This bit** of text\*", where the last asterisk
  is treated as regular text because it does not form a pair. Doing so avoids several edge cases and several problems
  that the parser may have to overcome. Markdown implements this same parsing order.

### Attached Modifiers and Their Functions
  Attached modifiers are those that change the look of a piece of text. Their symbols and functions are described here:
  - `*some text*` - marks text as **bold**
  - `_some text_` - marks text as _italic_
  - `~some text~` - marks text as ~~strikethrough~~. After researching \~\~this method\~\~ we have come to the conclusion
  	that it provides no advantage
  - `^some text^` - superscript
  - `|some text|` - spoilers
  - \`some text\` - inline code block

### Detached Modifiers and Their Functions
  Detached modifiers are those that change the way text is interpreted. Their symbols and functions are described in the format that follows:
  
  **A visual representation of the text -> \<regex\>**
  - `* Some text -> ^\s*\*\s+.+$` - marks text as a heading. Headings are one-line paragraphs
  - `** Some text -> ^\s*\*\*\s+.+$` - marks text as a subheading. Subheadings are one-line paragraphs
  - `*** Some text -> ^\s*\*\*\*\s+.+$` - marks text as a subsubheading. Subsubheadings are one-line paragraphs
  - `**** Some text -> ^\s*\*\*\*\*\s+.+$` - marks text as a subsubsubheading. Subsubsubheadings are one-line paragraphs
  - `- Do something -> ^\s*\-\s+.+$` - marks an unordered list
  - `- [ ] -> ^\s*\-\s+\[\s+\]\s+.+$` - marks an undone task
  - `- [*] -> ^\s*\-\s+\[\s*\*\s*\]\s+.+$` - marks a pending task
  - `- [x] -> ^\s*\-\s+\[\s*x\s*\]\s+.+$` - marks a complete (done) task
  - `| Important Information -> ^\s*\|\s+.+$` - symbolizes a marker
  - `> That's what she said -> ^\s*\>\s+.+$` - marks a quote

  - ```
    @document.meta
		<data>
    @end

	-> 

	^\s*\@[^\s]+\s*(([^\s]+\s*)*)$
		.*
	^\s*\@end\s*$
  	```
  	Marks a data tag, which you can read more about [here](#defining-data).

  - ```
    || My drawer!
		<content>
    ||

	-> 

	^\s*\|{2}\s+.+$
		.*
	^\s*\|{2}\s*$
  	```
  	Marks a drawer, which you can read more about [here](#drawers).

  - ```
    A [link](#my-link).

	->

	\s*\[.*\]\((((#|\*{1,4}|\||\|{2})[\-\w]+)|((((ht|f)tp(s?))\:\/\/)?(www.|[a-zA-Z].)[a-zA-Z0-9\-\.]+\.(com|edu|gov|mil|net|org|biz|info|name|museum|us|ca|uk)(\:[0-9]+)*(\/($|[a-zA-Z0-9\.\,\;\?\'\\\+&%\$#\=~_\-]+))*))\)
    ```
	Marks a link to another segment of a document or to a link on the web. More about it can be read [here](#links).

  - `$comment This is a comment! -> ^\s*\$[^\s]+\s*(([^\s]+\s*)*)$` - marks a carryover tag, which is essentially syntax sugar for a regular tag.
  	You can read more about it [here](#carryover-tags).

### Trailing Modifiers
  Trailing modifiers serve one purpose: change the way the next line is interpreted. This allows us to break some of the limitations
  that regular markdown imposes and allows us to further finely control the behaviour of the Neorg parser with little added complexity.
  Neorg currently supports one of these trailing modifiers: `~`.

  So, why do we need these trailing modifiers? Let's say you want to do this:
  ```
  * A heading that talks about some really super duper awesome things that I'm really excited to share
    with you tonight.
    Today I will be talking about...
  ```
  The issue? Your heading is really long, and you'd like to divide it into two lines. Although you shouldn't make your headings this long,
  it would be really nice to be able to tell Neorg to carry over to the next line and still treat is as part of that one line.
  Enter the `~` trailing modifier, that when placed at the end of a line, will allow you to concatenate two different lines and treat them
  as if they were one line. `~` adds one whitespace character just like a regular soft line break would.
  This feature is very useful to prevent the parser from interpreting a bit of raw text as a modifier, for example:
  ```
	And then I ventured through the forest~
	- I couldn't believe what I saw
  ```
  Using the `~` trailing modifier we prevent Neorg from interpreting the next line as an unordered list, and cause it to interpret
  the line as raw text instead, so the line becomes: `And then I ventured through the forest - I couldn't believe what I saw`.

### Escaping Special Characters
  Sometimes you'll find yourself not wanting to have a certain character format your text, you can directly prevent this
  by prefixing that character with a backslash `\`, like you would in Markdown. All characters are escapable in this fashion.

### Defining Data 
  What divides simple markdown files from more complex implementations is the ability to morph the document and define data inside the document.
  Neorg has a few ways of defining data, however it is not ultimately that complex. Let's review the methods of defining data:
  ```
  @my_data
	<any form of data>
  @end
  ```
  The `@` symbol, which defines the beginning of a **data tag** (more commonly referred to simply as a **tag**), allows the user to specify any bit of arbitrary data
  and label it with said tag. This data can then be referenced later on in the document, and different modules can also access this data and change it.
  One of the most notable inbuilt tags for Neorg is the `@document.meta` tag. Metadata is defined as such:
  ```
	@document.meta
		title: My Document
		description: Document description
		author: Vhyrro
		created: 2021-06-23
		categories: personal blogs neorg
		version: 0.1
	@end
  ```
  Tags must appear at the beginning of a line, and may optionally be preceded by whitespace. After that, any sort of text may be entered on as many lines
  as the user sees fit. The end of the data tag must be signalled with an `@end` token that must appear at the beginning of a line (with optional whitespace before it)
  and may not have any extra tokens after itself other than whitespace. This means that:
  ```
	VALID:
		@some.tag
			data goes here
			blah blah blah
		@end
	ALSO VALID (please don't do this):
			@some.tag   
			more data
			funny stuff
				@end   
	INVALID (last line gets treated as a continuation of the data and no end marker gets located):
		@some.tag
			text
		@end right now
	INVALID (tag definition has non-whitespace characters before itself):
		some pretext @some.tag
			text here
		@end
	ALSO INVALID (end token has non-whitespace characters beforehand):
		@some.tag
			text here
		the @end
  ```

#### Tag Parameters
  Tags may take in a certain amount of parameters, and these parameters can be supplied in a few different ways.
  For example, let's say we have a tag called `code` (which is a real tag btw!), and it takes in an optional parameter denoting
  the language. Neorg does not have multiline code blocks \`\`\`like this\`\`\` because such modifiers would directly break
  the imposed rules for attached modifiers, instead it uses the code tag:
  ```
	No parameter supplied, treated as a regular code block:
	@code
		console.log("Wow some code.")
	@end

	Parameter supplied, denotes the language via a parameter:
	@code lua
		print("Some awesome lua code!")
	@end
  ```
  Several parameters can be provided via space separation if the tag wants more than one parameter.

#### Carryover Tags
  Neorg provides a more convenient method of defining tags, one that does not require an `@end` token. These are called carryover tags,
  because they carry over and apply only to the next paragraph. They can be denoted with a `$` token, rather than a `@` token.
  Carryover tags are most commonly used with the `comment` tag, as writing:
  ```
	$comment This part of the document needs refactoring

	* Reasons why dark chocolate is better than white chocolate
    Over the years, several people have been asking themselves...
  ```

  Is much more convenient than writing:
  ```
	@comment
		This part of the document needs refactoring
	@end

	* Reasons why dark chocolate is better than white chocolate
    Over the years, several people have been asking themselves...
  ```
  Although both forms are correct. The `@` symbol for comments is only truly useful whenever you want to write mulitiline
  comments inside of your document. Inside of a carryover tag everything after the tag till the end of the line is counted as a
  parameter for that tag, as the body for that tag is the next paragraph.

##### Quirks
  Carryover tags have an interesting property when applied to lines with detached modifiers - as long as no
  hard line break (e.g. \n\n) is encountered, the carryover tag will "infect" all the other detached modifiers below it,
  let me show an example. Let's say, hypothetically, we have a `$color` tag, which allows us to change the colour
  of the next element. Because of this infectious property:

  ```
	$color red
	- One element
	- Another element
  ```

  Both the first and second list element will be affected by the `$color` tag, because the first element infected the other.
  In this scenario, the infection does not happen, and only the first list element gets the `$color` tag applied:

  ```
	$color red
	- One element

	- Unaffected element
  ```

  Because of the hard line break the second unordered list element gets unaffected. Just for clarity, this:

  ```
	$color red
	- One element
	  with some content on a newline
	- Another element
  ```

  **Will** cause the second element to get infected, because no hard line break occurs.

  Obviously, this rules applies to every detached modifier, even headings:
  ```
	$color red
	* A heading
	  ** A subheading
	     This regular text will be unaffected because it does not have a detached modifier.
  ```

  Both the heading and the subheading will become red, unless the subheading has a hard line break
  disconnecting the two.

  Another feature of carryover tags is their ability to carry over themselves and chain a bunch of
  tags together. For example, if I were to do:

  ```
	$color red
	$name my-heading
	* I like tomatoes
  ```

  The `$color` carryover tag will carry over to the `$name` tag, which will in turn carry over to the heading,
  creating a chain reaction. This is much more convenient than e.g. writing:

  ```
	@color red
		@name my-heading
			* I like tomatoes
		@end
	@end
  ```

### Single-line Paragraphs
  Single-line paragraphs are a special type of paragraph as they only exist for one line.
  We actually just had an encounter with such a paragraph with the data tags we discussed earlier.
  A data tag definition (like `@document.meta`) instantly breaks off as soon as the end of the line
  is reached, meaning that:
  ```
	@document
		.meta
  ```
  Will **not** result in the concatenation of both values to `@document.meta`, like it would in a normal paragraph,
  where:
  ```
	Some awesome
	text
  ```
  Gets concatenated into `Some awesome text`. This rule doesn't only apply to single-line paragraphs, as having to use a hard line-break
  like so:
  ```
	@document.meta

		key: value
	@end
  ```
  Would look incredibly ugly and would make it very confusing to people familiar with something called "logic".
  There are a few elements that use single-line paragraphs, these being:
  - Heading and all types of subheadings
  - Tag and carryover tag definitions
  
  This design decision is very logical, as writing:
  ```
	* Heading one
	This is some subtext for heading one
  ```
  Is a lot cleaner than having to place a hard line break:
  ```
	* Heading one

	This is some subtext for heading one
  ```
  Obviously, it is still possible to supply a hard line break, however both options are permitted. 
### Intersecting Modifiers
  Sometimes you may want to use modifiers while they're inside of a piece of text, like t**hi**s. Note how the **hi** is in bold.
  Neorg allows this, however it requires an extra step. According to the rules there must be whitespace/punctuation before
  an opening modifier and there must be whitespace/punctuation after a closing modifier. This means simply putting our modifiers inbetween
  our word l\*ik\*e so will not result in anything, as the modifiers break the defined rules. There is one extra rule, however - not only
  can these modifiers be prefixed/postfixed with whitespace or a punctuation mark, but they can also be prefixed/postfixed with *another modifier*.
  This is where the fun begins, enter the `-` modifier, except it's no ordinary modifier. It's a one-of-a-kind, in fact.
  This is the only modifier that does not fall into any of the 3 categories of modifiers (attached, detached and trailing). The `-`
  symbol is marked the **link modifier**. It exists to link different "categories" of text together.
  The rules for the link modifier are a twist on the rules of the attached modifier, meaning a link modifier must form a pair.
  An opening link modifier must be prefixed by a non-whitespace character and must be followed by an attached modifier.
  Note that the link modifier is **not** an attached modifier, so chaining them like `--` will simply result in the first hyphen
  being treated as punctuation. A closing link modifier may only be prefixed with an attached modifier and followed by a non-whitespace
  character. The syntactical equivalent of markdown's `so*me*thing` will look as such: `so-*me*-thing`. At first it looks weird, doesn't it? Hah.
  We believe that since you will find yourself injecting modifiers into a word rather infrequently it is worth trading some
  extra characters for infinitely more syntactical stability in the file format. Want to do something like `t**his black** magic`? You also can,
  like so: `t-*-his black* magic`. The imposed rules for both the opening and closing link modifier are still fulfilled, and as such
  you will get the result you'd expect - t**his black** magic.

### Lists
  Lists are ways of organizing text into several bullet points. There are two main types of list - unordered and ordered lists.
  Let's talk about them.

  To describe an unordered list, you may use the `-` detached modifier, which will result in this:
  ```
	- Do something
	- Do something else!
  ```
  There must be at least one bit of whitespace between the hyphen and the `D` for the unordered list to be considered as such.

  Ordered lists work a bit differently in Neorg, as they do not really have any syntax. Instead, they are constructed
  using a tag and also using [infecting](#quirks). There are two ways of creating ordered lists, and they look like this:

  ```
	The easiest way is by using the $ordered carryover tag:

	$ordered
	- Do something
	- Do something else

	You may also want to use the @ordered data tag if the side effects of infecting do not fit your needs:

	@ordered
		- Do something
		- Do something else

		- And also something else
	@end
  ```

  Using the `$ordered` and `@ordered` tags, you will get the following output:

  1. Do something
  2. Do something else

  and

  1. Do something
  2. Do something else
  3. And also something else

  respectfully.

  The `$ordered` tag has a few parameters, and they are:
  `$ordered start step spacing`.
  - `start` - signifies where to start counting from, default is `1`.
  - `step` - signifies how much to add between each list element, default step is `1`,
    if it were e.g. `2`, then the numbering would look like:
    ```
	1. First element
	3. Second element
	5. Third element
    ```
  - `spacing` - signifies how many newlines to add between each list element during the render,
    default is `1`.
    
### Nesting
  Nesting information can be very important to determine the layout of a document.
  Only items that contain a detached modifier can be nested in the way we will describe below.
  It is nice to be able to create e.g. nested lists, like so:
  ```
  - Do something
	- Another important thing
	- Another very important thing
  ```

  In Neorg even *one* extra space of indentation over the parent element causes the current line to be indented.
  This causes little hassle, little bugs, and makes sense from a user standpoint and from a technical standpoint.
  The parent element can only be another item that comprises of a detached modifier. The reason is that people often indent
  e.g. their lists one level further to the right so that the physical plaintext is easier to read and the list is easier
  to differentiate from the paragraph of raw text above. They usually do not want their lists to be indented an extra level during
  the document's render.

### TODO Lists
  TODO Items can be managed in a way that is practically the same as Markdown syntactically.
  ```
  - [ ] Do the dishes <- undone task
  - [*] Do the dishes <- pending task
  - [x] Do the dishes <- done task
  ```

  It is also possible to nest these in the same way as described [above](#nesting).
  The exact syntax (in regex) for these is described [here](#detached-modifiers-and-their-functions).

### Links
  <!-- I'm quite uncertain about the syntax for links and will gladly take into account any ideas
  you may have, just don't propose the org-mode syntax please -->

  Links are ways to connect several documents together and give the user access to special clickable hyperlinks.
  The syntax for links is derived from regular markdown, and looks as such:
  ```
	This is a [link](<anything here>)!
  ```

  The modifiers that comprise the link syntax are attached modifiers, however, the attached modifier
  rules only apply to the opening square bracket `[` and closing parenthesis `)`, aka the beginning and
  end of the link syntax. The modifiers inbetween may break these rules unfortunately :sob:.
  There are several things that can go into a link, so let's discuss:

#### The first segment
  The first segment of the link is the square [] brackets, where you can add some text to be displayed instead of the raw hyperlink.
  If you want to make a ] character as part of the link text then escape it with a backslash `\`. If no data is present
  inside the square brackets then the content of the second segment is used instead.

#### The second segment
  The second part is the one that comes after the square brackets and is supplied inbetween a pair of regular brackets `()`.
  The contents of this second segment can be several different things, and those things will be discussed here:
  ```
	* Example Heading
	** Example Subheading
	*** Example Subsubheading
	**** Example Subsubsubheading

	| A marker

	|| A drawer
		With some content
	||

	[text](https://github.com/vhyrro/neorg) - a regular domain name/hyperlink to a website
	[text](#Example Heading) - a link to any element with the text example-heading

	For more precision:
		[text](*Example Heading) - a link to a regular heading
		[text](**Example Subheading) - a link to a subheading
		[text](***Example Subsubheading) - a link to a subsubheading
		[text](****Example Subsubsubheading) - a link to a subsubsubheading
		[text](|A marker) - a link to a marker
		[text](||A drawer) - a link to a drawer
  ```

  Neorg uses the first set of non-alphanumeric characters to determine what type of element it should link to.
  Afterwards, it will check the document from top to bottom for that element and provide the first found match as the link.
  If there is no special non-alphanumeric character after the opening bracket `(` then the text is counted as a hyperlink,
  even if it is an incorrect hyperlink.
  
  Searching is case insensitive, meaning `[text](*Example Heading)` and `[text](*example heading)` link to the same
  location. Neorg will search through all files and directories recursively in the current workspace.
  Workspaces can be defined by the application managing the .norg files or by e.g. a Neorg module.
  The easiest implementation of a workspace would be to simply set the workspace root to the current working directory of
  the file and search from there. You can explicitly specify the file where Neorg should look for the
  link we specified. The syntax for it is as such:

  ```
	[text](file:#Location)
  ```

  To specify several files to search through, you can do:
  ```
	[text](file:other_file:#Location)
  ```

  If a filename has any special characters that may interfere, you must escape those characters with a backslash `\`.

  For parser implementers: It may have caught your attention that headings and such can have
  their own `:` chars in them - to recognize the _real_ last element you may want to look for the `:` char
  that has a special character like `#`, `*` or `|` after itself - that way you won't have problems with differentiating
  the different parts of text. URLs can be differentiated too as they need to have a `//` after the `:` character to denote
  the protocol used, and so you may use this to your advantage to determine whether the supplied data is a URL, a filename, etc.

### Markers
  Markers are ways to create easy "checkpoints" within your document. These can be referenced in [links](#links)
  and can be jumped to at any time. To define a marker, we may use a single pipe symbol `|`.

  ```
	I have some cool text here. You may be interested in checking out [this other cool text](|my-special-marker).

	* You won't believe how much money she made with this one simple trick!

| My Special Marker

	* Actual important things you should know about
		I have some more cool text here.
	* Work stuff:
	  - [x] Throw banana at boss's massive 4head
  ```

  It is also possible to give your marker a special name by using the `$name` tag to reference it in links, like so:
  ```
	$name marker1
	| My Special Marker

	$comment Reference the marker with its custom name
	I have a link to my marker right [here](#marker1).
  ```

### Drawers
  Drawers are designed on the same principles as org mode's `drawers` are. It allows you to categorize a bit of text
  and hide it away at any given moment. The syntax for drawers is as follows:
  ```
	I really want to be able to hide this bit of text, if only there was a way for me to do that:

	|| My hidden text
   	   I want to collapse this text!
	||
  ```

  As with everything else, using the `$name` carryover tag will allow you to reference the drawer with a custom name.

# Data Tags
Neorg provides several inbuilt data tags to represent different things. Those exact things will be detailed here:
- `@document.meta` - describes metadata about the document. Attributes are stored as key-value pairs. Values may have
  attached and trailing modifiers in them. The trailing modifiers should be respected and the attached modifiers
  should only really be taken into account if that metadata is being rendered somewhere.
  
  Example:
	```
	@document.meta
		title: My Document <- The title of the document
		description: This is my document that details the reasons~
		why Neorg is the best file format. <- The description of the document
		author: Vhyrro <- The name of the author
		created: 2021-06-23 <- The date of creation in the Y-M-D format
		categories: personal blogs neorg <- Space separated list of categories
		version: 0.1 <- The version of the file format used to create the document
	@end
	```

	It is not recommended to use the `$` equivalent for this tag.

- `@comment` - simply signals a comment. Using the comment tag with the `@` symbol makes
			   it a multiline comment, however using carryover tags allows you to supply only
			   a single-line comment. 

<!-- Gotta love markdown formatting: -->

Examples:

```
@comment
	This is a comment!
	And it can span across multiple lines too!
end

$comment And this is a single-line comment, because they're cool!
```

- `@table` - defines a Neorg table. Tables do not currently have the immense power of org-mode tables,
  however serve a basic function for now. They simply contain some text. Here's the format for said tables:
	```
	@table
		This is a row | And another element of that row
		This is a row on a new column | And another element of that row
		-
		The above line marks a delimiter
	@end
	```

  After rendering the table it should look like:
  ```
  |         This is a row         | And another element of that row |
  | This is a row on a new column | And another element of that row |
  | ----------------------------- | ------------------------------- | 
  |                The above line marks a delimiter                 |
  ```

  If you wanted to prevent the bottom line from filling up the entire space, you'd do:
  ```
	@table
		This is a row | And another element of that row
		This is a row on a new column | And another element of that row
		-
		The above line marks a delimiter | 
	@end
  ```

  And you'd get:
  ```
  |          This is a row           | And another element of that row |
  |  This is a row on a new column   | And another element of that row |
  | -------------------------------- | ------------------------------- | 
  | The above line marks a delimiter |                                 |
  ```

  If the content of the cell has a newline then that newline gets converted into a `\n` sequence.

- `@ordered` - marks the next element as an ordered list if that next element is an unordered list.

  The `@ordered` tag has a few parameters, and they are:
  `@ordered start step spacing`.
  - `start` - signifies where to start counting from, default is `1`.
  - `step` - signifies how much to add between each list element, default step is `1`,
    if it were e.g. `2`, then the numbering would look like:
    ```
	1. First element
	3. Second element
	5. Third element
    ```
  - `spacing` - signifies how many newlines to add between each list element during the render,
    default is `1`.

  The carryover tag version can be used with "infecting" to achieve a nice result.

- `$name name` - gives the next element with a detached modifier a custom name that can then be used to
  reference it in links if that next element has a detached modifier.

  Example:
  ```
  $name mycustomname
  $name anothername
  * My Heading

  You can reference the document [here](#mycustomname) and [here](#anothername).
  ```

- `@image format` - stores an image within the file. The content of this image should be a base64 encoded jpeg, png, svg, jfif or exif file.
  The only parameter, `format`, specifies which format the image was encoded in. Defaults to `PNG` if unspecified.

- `$embed type uri` - embeds an element directly into the document, for example an image, a GIF, or any other kind of media that is supported.
  The `type` parameter can be one of two values: `video` or `image`.

  The `@` version of this tag is not recommended, as it would simply look like this:
  ```
	@embed image /my/image
	@end
  ```
  Which is rather redundant compared to simply writing `$embed image /my/image`.
  The root, `/`, should be the root of the current workspace, not the root of the filesystem.

### Unsupported Tags 
  If a tag is encountered that is invalid it should simply be ignored and never showed in any render of the document.
