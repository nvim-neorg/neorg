(ranged_verbatim_tag
  ("_prefix") @neorg.tags.ranged_verbatim.begin
  name: (tag_name
          [(word) @neorg.tags.ranged_verbatim.name.word
           ("_delimiter") @neorg.tags.ranged_verbatim.name.delimiter]) @neorg.tags.ranged_verbatim.name
  (tag_parameters
    (tag_param) @neorg.tags.ranged_verbatim.parameters.word)? @neorg.tags.ranged_verbatim.parameters)

(ranged_verbatim_tag_end
    ("_prefix") @neorg.tags.ranged_verbatim.end
    ("_name") @neorg.tags.ranged_verbatim.name.word)

(ranged_verbatim_tag
  ("_prefix")
  name: (tag_name) @neorg.tags.ranged_verbatim.name
  (#eq? @neorg.tags.ranged_verbatim.name "comment")
  content: (ranged_verbatim_tag_content)? @neorg.tags.comment.content)

(paragraph
  (strong_carryover_set
    (strong_carryover
      name: (tag_name) @_name
      (#eq? @_name "comment")))
  (paragraph_segment) @neorg.tags.comment.content)

(strong_carryover
  ("_prefix" @neorg.tags.carryover.begin)
  name: (tag_name
          [(word) @neorg.tags.carryover.name.word
           ("_delimiter") @neorg.tags.carryover.name.delimiter]) @neorg.tags.carryover.name
    (tag_parameters
      (tag_param) @neorg.tags.carryover.parameters.word)? @neorg.tags.carryover.parameters) @neorg.tags.carryover

; Trailing Modifier
("_trailing_modifier") @neorg.modifiers.trailing

; Link Modifier
(link_modifier) @neorg.modifiers.link

; Links
(link
  (link_location
    ("_begin") @neorg.links.location.delimiter
    [(("_begin") @neorg.links.file.delimiter
        file: (link_file_text) @neorg.links.file
        ("_end") @neorg.links.file.delimiter)
     ((link_target_url) ; Doesn't require a highlight since it's a 0-width node
        (paragraph) @neorg.links.location.url)
     ((link_target_generic) @neorg.links.location.generic.prefix
        (paragraph) @neorg.links.location.generic)
     ((link_target_external_file) @neorg.links.location.external_file.prefix
        (paragraph) @neorg.links.location.external_file)
     ((link_target_definition) @neorg.links.location.definition.prefix
        (paragraph) @neorg.links.location.definition)
     ((link_target_footnote) @neorg.links.location.footnote.prefix
        (paragraph) @neorg.links.location.footnote)
     ((link_target_heading1) @neorg.links.location.heading.1.prefix
        (paragraph) @neorg.links.location.heading.1)
     ((link_target_heading2) @neorg.links.location.heading.2.prefix
        (paragraph) @neorg.links.location.heading.2)
     ((link_target_heading3) @neorg.links.location.heading.3.prefix
        (paragraph) @neorg.links.location.heading.3)
     ((link_target_heading4) @neorg.links.location.heading.4.prefix
        (paragraph) @neorg.links.location.heading.4)
     ((link_target_heading5) @neorg.links.location.heading.5.prefix
        (paragraph) @neorg.links.location.heading.5)
     ((link_target_heading6) @neorg.links.location.heading.6.prefix
        (paragraph) @neorg.links.location.heading.6)
     ((link_target_wiki) @neorg.links.location.wiki.prefix
        (paragraph) @neorg.links.location.wiki)
     ((link_target_timestamp) @neorg.links.location.timestamp.prefix
        (paragraph) @neorg.links.location.timestamp)]
    ("_end") @neorg.links.location.delimiter)
  (link_description
    ("_begin") @neorg.links.description.delimiter
    text: (paragraph) @neorg.links.description
    ("_end") @neorg.links.description.delimiter)?)

; Anchors
(anchor_declaration
  (link_description
    ("_begin") @neorg.anchors.declaration.delimiter
    text: (paragraph) @neorg.anchors.declaration
    ("_end") @neorg.anchors.declaration.delimiter))

(anchor_definition
    (link_description
        ("_begin") @neorg.anchors.definition.delimiter
        text: (paragraph) @neorg.anchors.declaration
        ("_end") @neorg.anchors.definition.delimiter) @neorg.anchors
    (link_location
      ("_begin") @neorg.links.location.delimiter
      [(("_begin") @neorg.links.file.delimiter
          file: (link_file_text) @neorg.links.file
          ("_end") @neorg.links.file.delimiter)
       ((link_target_url) ; Doesn't require a highlight since it's a 0-width node
          (paragraph) @neorg.links.location.url)
       ((link_target_generic) @neorg.links.location.generic.prefix
          (paragraph) @neorg.links.location.generic)
       ((link_target_external_file) @neorg.links.location.external_file.prefix
          (paragraph) @neorg.links.location.external_file)
       ((link_target_definition) @neorg.links.location.definition.prefix
          (paragraph) @neorg.links.location.definition)
       ((link_target_footnote) @neorg.links.location.footnote.prefix
          (paragraph) @neorg.links.location.footnote)
       ((link_target_heading1) @neorg.links.location.heading.1.prefix
          (paragraph) @neorg.links.location.heading.1)
       ((link_target_heading2) @neorg.links.location.heading.2.prefix
          (paragraph) @neorg.links.location.heading.2)
       ((link_target_heading3) @neorg.links.location.heading.3.prefix
          (paragraph) @neorg.links.location.heading.3)
       ((link_target_heading4) @neorg.links.location.heading.4.prefix
          (paragraph) @neorg.links.location.heading.4)
       ((link_target_heading5) @neorg.links.location.heading.5.prefix
          (paragraph) @neorg.links.location.heading.5)
       ((link_target_heading6) @neorg.links.location.heading.6.prefix
          (paragraph) @neorg.links.location.heading.6)
       ((link_target_wiki) @neorg.links.location.wiki.prefix
          (paragraph) @neorg.links.location.wiki)
       ((link_target_timestamp) @neorg.links.location.timestamp.prefix
          (paragraph) @neorg.links.location.timestamp)]
      ("_end") @neorg.links.location.delimiter))

; Headings
(heading1
  (heading1_prefix) @neorg.headings.1.prefix
  title: (paragraph_segment) @neorg.headings.1.title)
(heading2
  (heading2_prefix) @neorg.headings.2.prefix
  title: (paragraph_segment) @neorg.headings.2.title)
(heading3
  (heading3_prefix) @neorg.headings.3.prefix
  title: (paragraph_segment) @neorg.headings.3.title)
(heading4
  (heading4_prefix) @neorg.headings.4.prefix
  title: (paragraph_segment) @neorg.headings.4.title)
(heading5
  (heading5_prefix) @neorg.headings.5.prefix
  title: (paragraph_segment) @neorg.headings.5.title)
(heading6
  (heading6_prefix) @neorg.headings.6.prefix
  title: (paragraph_segment) @neorg.headings.6.title)

; Display errors
(ERROR) @neorg.error

; Definitions
(single_definition
  (single_definition_prefix) @neorg.definitions.prefix
  title: (paragraph_segment) @neorg.definitions.title
  content: [(_) "_paragraph_break"]* @neorg.definitions.content)
(multi_definition
  (multi_definition_prefix) @neorg.definitions.prefix
  title: (paragraph_segment) @neorg.definitions.title
  content: [(_) "_paragraph_break"]* @neorg.definitions.content
  end: (multi_definition_suffix) @neorg.definitions.suffix)

; Footnotes
(single_footnote
  (single_footnote_prefix) @neorg.footnotes.prefix
  title: (paragraph_segment) @neorg.footnotes.title
  content: [(_) "_paragraph_break"]* @neorg.footnotes.content)
(multi_footnote
  (multi_footnote_prefix) @neorg.footnotes.prefix
  title: (paragraph_segment) @neorg.footnotes.title
  content: [(_) "_paragraph_break"]* @neorg.footnotes.content
  end: (multi_footnote_suffix) @neorg.footnotes.suffix)

; Escape sequences (\char)
(escape_sequence) @neorg.modifiers.escape

; Detached Modifier extensions
(detached_modifier_extension (todo_item_undone)) @neorg.todo_items.undone
(detached_modifier_extension (todo_item_done)) @neorg.todo_items.done
(detached_modifier_extension (todo_item_pending)) @neorg.todo_items.pending
(detached_modifier_extension (todo_item_on_hold)) @neorg.todo_items.on_hold
(detached_modifier_extension (todo_item_cancelled)) @neorg.todo_items.cancelled
(detached_modifier_extension (todo_item_uncertain)) @neorg.todo_items.uncertain
(detached_modifier_extension (todo_item_urgent)) @neorg.todo_items.urgent
(detached_modifier_extension (todo_item_recurring)) @neorg.todo_items.recurring

; ; Unordered lists
[(unordered_list1_prefix)
 (unordered_list2_prefix)
 (unordered_list3_prefix)
 (unordered_list4_prefix)
 (unordered_list5_prefix)
 (unordered_list6_prefix)] @neorg.lists.unordered.prefix

; Ordered lists
[(ordered_list1_prefix)
 (ordered_list2_prefix)
 (ordered_list3_prefix)
 (ordered_list4_prefix)
 (ordered_list5_prefix)
 (ordered_list6_prefix)] @neorg.lists.ordered.prefix

; Quotes
(quote1
  (quote1_prefix) @neorg.quotes.1.prefix
  content: (paragraph) @neorg.quotes.1.content)
(quote2
  (quote2_prefix) @neorg.quotes.2.prefix
  content: (paragraph) @neorg.quotes.2.content)
(quote3
  (quote3_prefix) @neorg.quotes.3.prefix
  content: (paragraph) @neorg.quotes.3.content)
(quote4
  (quote4_prefix) @neorg.quotes.4.prefix
  content: (paragraph) @neorg.quotes.4.content)
(quote5
  (quote5_prefix) @neorg.quotes.5.prefix
  content: (paragraph) @neorg.quotes.5.content)
(quote6
  (quote6_prefix) @neorg.quotes.6.prefix
  content: (paragraph) @neorg.quotes.6.content)

; Paragraph Delimiters
(strong_paragraph_delimiter) @neorg.delimiters.strong
(weak_paragraph_delimiter) @neorg.delimiters.weak
(horizontal_line) @neorg.delimiters.horizontal_line

; Markup
(bold ["_open" "_close"] @neorg.markup.bold.delimiter) @neorg.markup.bold
(italic ["_open" "_close"] @neorg.markup.italic.delimiter) @neorg.markup.italic
(strikethrough ["_open" "_close"] @neorg.markup.strikethrough.delimiter) @neorg.markup.strikethrough
(underline ["_open" "_close"] @neorg.markup.underline.delimiter) @neorg.markup.underline
(spoiler ["_open" "_close"] @neorg.markup.spoiler.delimiter) @neorg.markup.spoiler
(verbatim ["_open" "_close"] @neorg.markup.verbatim.delimiter) @neorg.markup.verbatim
(superscript ["_open" "_close"] @neorg.markup.superscript.delimiter) @neorg.markup.superscript
(subscript ["_open" "_close"] @neorg.markup.subscript.delimiter) @neorg.markup.subscript
(inline_comment ["_open" "_close"] @neorg.markup.inline_comment.delimiter) @neorg.markup.inline_comment
(inline_math ["_open" "_close"] @neorg.markup.inline_math.delimiter) @neorg.markup.inline_math
(inline_macro ["_open" "_close"] @neorg.markup.variable.delimiter) @neorg.markup.variable

; Free-form Markup
[(free_form_open)
 (free_form_close)] @neorg.markup.free_form_delimiter

(superscript
  (subscript) @neorg.error
  (#set! priority 300))
(subscript
  (superscript) @neorg.error
  (#set! priority 300))

; Comments
(inline_comment) @comment

; Conceals
(
    [
        "_open"
        "_close"
        "_trailing_modifier"
        (link_modifier)
        (free_form_open)
        (free_form_close)
    ] @conceal
    (#set! conceal "")
)

(
    [
        (link_description
            [
                "_begin"
                type: (_)
                "_end"
            ] @conceal
        )
        (link_location
            [
                "_begin"
                type: (_)
                "_end"
            ] @conceal
        )
        (link
            (link_location) @conceal
            (link_description)
        )
    ]
    (#set! conceal "")
)

(
    [
        (anchor_definition
            (link_description)
            (link_location) @conceal
        )
    ]
    (#set! conceal "")
)

(
    (escape_sequence_prefix) @conceal
    (#set! conceal "")
)

; Spell
(paragraph_segment) @spell
