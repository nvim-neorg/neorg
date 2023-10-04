(verbatim_ranged_tag
  "@" @neorg.tags.ranged_verbatim
  (tag_name
    [(identifier) @neorg.tags.ranged_verbatim.name.word
                  "." @neorg.tags.ranged_verbatim.name.delimiter]) @neorg.tags.ranged_verbatim.name
  (parameter)* @neorg.tags.ranged_verbatim.parameters.word
  (end) @neorg.tags.ranged_verbatim)

(verbatim_ranged_tag
  "@" @neorg.tags.ranged_verbatim
  (tag_name) @neorg.tags.ranged_verbatim.name
  (#eq? @neorg.tags.ranged_verbatim.name "comment")
  (verbatim_content)? @neorg.tags.comment.content)

(
    (strong_carryover_tag
      (tag_name) @_name
      (#eq? @_name "comment"))
    .
    (paragraph) @neorg.tags.comment.content
 )


(strong_carryover_tag
  "#" @neorg.tags.carryover.begin
  (tag_name
          [(identifier) @neorg.tags.carryover.name.word
           "." @neorg.tags.carryover.name.delimiter]) @neorg.tags.carryover.name
      (parameter)* @neorg.tags.carryover.parameters.word) @neorg.tags.carryover

; Link Modifier
(link_modifier) @neorg.modifiers.link

; Links
; (link
;   (link_location
;     ("_begin") @neorg.links.location.delimiter
;     [(("_begin") @neorg.links.file.delimiter
;         file: (link_file_text) @neorg.links.file
;         ("_end") @neorg.links.file.delimiter)
;      ((link_target_url) ; Doesn't require a highlight since it's a 0-width node
;         (paragraph) @neorg.links.location.url)
;      ((link_target_generic) @neorg.links.location.generic.prefix
;         (paragraph) @neorg.links.location.generic)
;      ((link_target_external_file) @neorg.links.location.external_file.prefix
;         (paragraph) @neorg.links.location.external_file)
;      ((link_target_definition) @neorg.links.location.definition.prefix
;         (paragraph) @neorg.links.location.definition)
;      ((link_target_footnote) @neorg.links.location.footnote.prefix
;         (paragraph) @neorg.links.location.footnote)
;      ((link_target_heading1) @neorg.links.location.heading.1.prefix
;         (paragraph) @neorg.links.location.heading.1)
;      ((link_target_heading2) @neorg.links.location.heading.2.prefix
;         (paragraph) @neorg.links.location.heading.2)
;      ((link_target_heading3) @neorg.links.location.heading.3.prefix
;         (paragraph) @neorg.links.location.heading.3)
;      ((link_target_heading4) @neorg.links.location.heading.4.prefix
;         (paragraph) @neorg.links.location.heading.4)
;      ((link_target_heading5) @neorg.links.location.heading.5.prefix
;         (paragraph) @neorg.links.location.heading.5)
;      ((link_target_heading6) @neorg.links.location.heading.6.prefix
;         (paragraph) @neorg.links.location.heading.6)
;      ((link_target_wiki) @neorg.links.location.wiki.prefix
;         (paragraph) @neorg.links.location.wiki)
;      ((link_target_timestamp) @neorg.links.location.timestamp.prefix
;         (paragraph) @neorg.links.location.timestamp)]
;     ("_end") @neorg.links.location.delimiter)
;   (link_description
;     ("_begin") @neorg.links.description.delimiter
;     text: (paragraph) @neorg.links.description
;     ("_end") @neorg.links.description.delimiter)?)
; 
; ; Anchors
; (anchor_declaration
;   (link_description
;     ("_begin") @neorg.anchors.declaration.delimiter
;     text: (paragraph) @neorg.anchors.declaration
;     ("_end") @neorg.anchors.declaration.delimiter))
; 
; (anchor_definition
;     (link_description
;         ("_begin") @neorg.anchors.definition.delimiter
;         text: (paragraph) @neorg.anchors.declaration
;         ("_end") @neorg.anchors.definition.delimiter) @neorg.anchors
;     (link_location
;       ("_begin") @neorg.links.location.delimiter
;       [(("_begin") @neorg.links.file.delimiter
;           file: (link_file_text) @neorg.links.file
;           ("_end") @neorg.links.file.delimiter)
;        ((link_target_url) ; Doesn't require a highlight since it's a 0-width node
;           (paragraph) @neorg.links.location.url)
;        ((link_target_generic) @neorg.links.location.generic.prefix
;           (paragraph) @neorg.links.location.generic)
;        ((link_target_external_file) @neorg.links.location.external_file.prefix
;           (paragraph) @neorg.links.location.external_file)
;        ((link_target_definition) @neorg.links.location.definition.prefix
;           (paragraph) @neorg.links.location.definition)
;        ((link_target_footnote) @neorg.links.location.footnote.prefix
;           (paragraph) @neorg.links.location.footnote)
;        ((link_target_heading1) @neorg.links.location.heading.1.prefix
;           (paragraph) @neorg.links.location.heading.1)
;        ((link_target_heading2) @neorg.links.location.heading.2.prefix
;           (paragraph) @neorg.links.location.heading.2)
;        ((link_target_heading3) @neorg.links.location.heading.3.prefix
;           (paragraph) @neorg.links.location.heading.3)
;        ((link_target_heading4) @neorg.links.location.heading.4.prefix
;           (paragraph) @neorg.links.location.heading.4)
;        ((link_target_heading5) @neorg.links.location.heading.5.prefix
;           (paragraph) @neorg.links.location.heading.5)
;        ((link_target_heading6) @neorg.links.location.heading.6.prefix
;           (paragraph) @neorg.links.location.heading.6)
;        ((link_target_wiki) @neorg.links.location.wiki.prefix
;           (paragraph) @neorg.links.location.wiki)
;        ((link_target_timestamp) @neorg.links.location.timestamp.prefix
;           (paragraph) @neorg.links.location.timestamp)]
;       ("_end") @neorg.links.location.delimiter))

; Headings
(heading
  (heading_stars) @neorg.headings.1.prefix
  (#eq? @neorg.headings.1.prefix "*")
  (title) @neorg.headings.1.title)

(heading
  (heading_stars) @neorg.headings.2.prefix
  (#eq? @neorg.headings.2.prefix "**")
  (title) @neorg.headings.2.title)

(heading
  (heading_stars) @neorg.headings.3.prefix
  (#eq? @neorg.headings.3.prefix "***")
  (title) @neorg.headings.3.title)

(heading
  (heading_stars) @neorg.headings.4.prefix
  (#eq? @neorg.headings.4.prefix "****")
  (title) @neorg.headings.4.title)

(heading
  (heading_stars) @neorg.headings.5.prefix
  (#eq? @neorg.headings.5.prefix "*****")
  (title) @neorg.headings.5.title)

(heading
  (heading_stars) @neorg.headings.6.prefix
  (#eq? @neorg.headings.6.prefix "******")
  (title) @neorg.headings.6.title)

; Display errors
(ERROR) @neorg.error

; Definitions
(definition_list_single
  (definition_single_prefix) @neorg.definitions.prefix
  (title) @neorg.definitions.title
  (paragraph) @neorg.definitions.content)

(definition_list_multi
  (definition_multi_prefix) @neorg.definitions.prefix
  (title) @neorg.definitions.title
  _* @neorg.definitions.content
  (definition_multi_end) @neorg.definitions.suffix)

; Footnotes
(footnote_list_single
  (footnote_single_prefix) @neorg.footnotes.prefix
  (title) @neorg.footnotes.title
  (paragraph) @neorg.footnotes.content)

(footnote_list_multi
  (footnote_multi_prefix) @neorg.footnotes.prefix
  (title) @neorg.footnotes.title
  _* @neorg.footnotes.content
  (footnote_multi_end) @neorg.footnotes.suffix)

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
(unordered_list_prefix) @neorg.lists.unordered.prefix

; Ordered lists
(ordered_list_prefix) @neorg.lists.ordered.prefix

; Quotes
(quote_item
  (quote_prefix) @neorg.quotes.1.prefix
  (#eq? @neorg.quotes.1.prefix ">")
  (paragraph) @neorg.quotes.1.content)
(quote_item
  (quote_prefix) @neorg.quotes.2.prefix
  (#eq? @neorg.quotes.2.prefix ">>")
  (paragraph) @neorg.quotes.2.content)
(quote_item
  (quote_prefix) @neorg.quotes.3.prefix
  (#eq? @neorg.quotes.3.prefix ">>>")
  (paragraph) @neorg.quotes.3.content)
(quote_item
  (quote_prefix) @neorg.quotes.4.prefix
  (#eq? @neorg.quotes.4.prefix ">>>>")
  (paragraph) @neorg.quotes.4.content)
(quote_item
  (quote_prefix) @neorg.quotes.5.prefix
  (#eq? @neorg.quotes.5.prefix ">>>>>")
  (paragraph) @neorg.quotes.5.content)
(quote_item
  (quote_prefix) @neorg.quotes.6.prefix
  (#eq? @neorg.quotes.6.prefix ">>>>>>")
  (paragraph) @neorg.quotes.6.content)

; Paragraph Delimiters
(strong_delimiting_modifier) @neorg.delimiters.strong
(weak_delimiting_modifier) @neorg.delimiters.weak
(horizontal_line) @neorg.delimiters.horizontal_line

; Markup
(bold [(open) (close)] @neorg.markup.bold.delimiter) @neorg.markup.bold
(italic [(open) (close)] @neorg.markup.italic.delimiter) @neorg.markup.italic
(strikethrough [(open) (close)] @neorg.markup.strikethrough.delimiter) @neorg.markup.strikethrough
(underline [(open) (close)] @neorg.markup.underline.delimiter) @neorg.markup.underline
(spoiler [(open) (close)] @neorg.markup.spoiler.delimiter) @neorg.markup.spoiler
(verbatim [(open) (close)] @neorg.markup.verbatim.delimiter) @neorg.markup.verbatim
(superscript [(open) (close)] @neorg.markup.superscript.delimiter) @neorg.markup.superscript
(subscript [(open) (close)] @neorg.markup.subscript.delimiter) @neorg.markup.subscript
; (inline_comment [(open) (close)] @neorg.markup.inline_comment.delimiter) @neorg.markup.inline_comment
; (inline_math [(open) (close)] @neorg.markup.inline_math.delimiter) @neorg.markup.inline_math
; (inline_macro [(open) (close)] @neorg.markup.variable.delimiter) @neorg.markup.variable

; Free-form Markup
; [(free_form_open)
; (free_form_close)] @neorg.markup.free_form_delimiter

(superscript
  (subscript) @neorg.error
  (#set! priority 300))
(subscript
  (superscript) @neorg.error
  (#set! priority 300))

; Comments
; (inline_comment) @comment

; Conceals
(
    [
        (open)
        (close)
        (link_modifier)
        ; (free_form_open)
        ; (free_form_close)
    ] @conceal
    (#set! conceal "")
)

; (
;     [
;         (link_description
;             [
;                 "_begin"
;                 type: (_)
;                 "_end"
;             ] @conceal
;         )
;         (link_location
;             [
;                 "_begin"
;                 type: (_)
;                 "_end"
;             ] @conceal
;         )
;         (link
;             (link_location) @conceal
;             (link_description)
;         )
;     ]
;     (#set! conceal "")
; )
; 
; (
;     [
;         (anchor_definition
;             (link_description)
;             (link_location) @conceal
;         )
;     ]
;     (#set! conceal "")
; )

(escape_sequence
    "\\" @conceal
    (#set! conceal "")
)

; Spell
(paragraph) @spell
