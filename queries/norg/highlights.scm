(ranged_tag ("_prefix") @neorg.tags.ranged_verbatim.begin
	name: (tag_name [(tag_name_element) @neorg.tags.ranged_verbatim.name.word ("_delimiter") @neorg.tags.ranged_verbatim.name.delimiter]) @neorg.tags.ranged_verbatim.name
	(tag_parameters parameter: (tag_param) @neorg.tags.ranged_verbatim.parameters.word)? @neorg.tags.ranged_verbatim.parameters
	content: (ranged_tag_content)?
	(ranged_tag_end ("_prefix") @neorg.tags.ranged_verbatim.end ("_name") @neorg.tags.ranged_verbatim.name.word))

(ranged_tag ("_prefix")
	name: (tag_name) @neorg.tags.ranged_verbatim.name (#eq? @neorg.tags.ranged_verbatim.name "comment")
	content: (ranged_tag_content)? @neorg.tags.comment.content)

(carryover_tag_set
  (carryover_tag
    name: (tag_name) @_name
    (#eq? @_name "comment"))
    target: (paragraph) @neorg.tags.comment.content)

(carryover_tag_set
    (carryover_tag
        ("_prefix" @neorg.tags.carryover.begin)
        name:
            (tag_name
                [
                    (tag_name_element) @neorg.tags.carryover.name.word
                    ("_delimiter") @neorg.tags.carryover.name.delimiter
                ]
            ) @neorg.tags.carryover.name
        (tag_parameters
            parameter: (tag_param) @neorg.tags.carryover.parameters.word
        )? @neorg.tags.carryover.parameters
    ) @neorg.tags.carryover

	target: (_) @neorg.tags.carryover.target
)

; Trailing Modifier
("_trailing_modifier") @neorg.modifiers.trailing

; Link Modifier
(link_modifier) @neorg.modifiers.link

; Links
(link
    (link_location
        ("_begin") @neorg.links.location.delimiter
        [
            (
                ("_begin") @neorg.links.file.delimiter
                file: (link_file_text) @neorg.links.file
                ("_end") @neorg.links.file.delimiter
            )
            (
                (link_target_url) ; Doesn't require a highlight since it's a 0-width node
                (paragraph_segment) @neorg.links.location.url
            )
            (
                (link_target_generic) @neorg.links.location.generic.prefix
                (paragraph_segment) @neorg.links.location.generic
            )
            (
                (link_target_external_file) @neorg.links.location.external_file.prefix
                (paragraph_segment) @neorg.links.location.external_file
            )
            (
                (link_target_marker) @neorg.links.location.marker.prefix
                (paragraph_segment) @neorg.links.location.marker
            )
            (
                (link_target_definition) @neorg.links.location.definition.prefix
                (paragraph_segment) @neorg.links.location.definition
            )
            (
                (link_target_footnote) @neorg.links.location.footnote.prefix
                (paragraph_segment) @neorg.links.location.footnote
            )
            (
                (link_target_heading1) @neorg.links.location.heading.1.prefix
                (paragraph_segment) @neorg.links.location.heading.1
            )
            (
                (link_target_heading2) @neorg.links.location.heading.2.prefix
                (paragraph_segment) @neorg.links.location.heading.2
            )
            (
                (link_target_heading3) @neorg.links.location.heading.3.prefix
                (paragraph_segment) @neorg.links.location.heading.3
            )
            (
                (link_target_heading4) @neorg.links.location.heading.4.prefix
                (paragraph_segment) @neorg.links.location.heading.4
            )
            (
                (link_target_heading5) @neorg.links.location.heading.5.prefix
                (paragraph_segment) @neorg.links.location.heading.5
            )
            (
                (link_target_heading6) @neorg.links.location.heading.6.prefix
                (paragraph_segment) @neorg.links.location.heading.6
            )
        ]
        ("_end") @neorg.links.location.delimiter
    )
    (link_description
        ("_begin") @neorg.links.description.delimiter
        text: (paragraph_segment) @neorg.links.description
        ("_end") @neorg.links.description.delimiter
    )?
)

; Anchors
(anchor_declaration
    (link_description
        ("_begin") @neorg.anchors.declaration.delimiter
        text: (paragraph_segment) @neorg.anchors.declaration
        ("_end") @neorg.anchors.declaration.delimiter
    )
)

(anchor_definition
    (link_description
        ("_begin") @neorg.anchors.definition.delimiter
        text: (paragraph_segment) @neorg.anchors.declaration
        ("_end") @neorg.anchors.definition.delimiter
    ) @neorg.anchors
    (link_location
        ("_begin") @neorg.links.location.delimiter
        [
            (
                ("_begin") @neorg.links.file.delimiter
                file: (link_file_text) @neorg.links.file
                ("_end") @neorg.links.file.delimiter
            )
            (
                (link_target_url) ; Doesn't require a highlight since it's a 0-width node
                (paragraph_segment) @neorg.links.location.url
            )
            (
                (link_target_generic) @neorg.links.location.generic.prefix
                (paragraph_segment) @neorg.links.location.generic
            )
            (
                (link_target_external_file) @neorg.links.location.external_file.prefix
                (paragraph_segment) @neorg.links.location.external_file
            )
            (
                (link_target_marker) @neorg.links.location.marker.prefix
                (paragraph_segment) @neorg.links.location.marker
            )
            (
                (link_target_definition) @neorg.links.location.definition.prefix
                (paragraph_segment) @neorg.links.location.definition
            )
            (
                (link_target_footnote) @neorg.links.location.footnote.prefix
                (paragraph_segment) @neorg.links.location.footnote
            )
            (
                (link_target_heading1) @neorg.links.location.heading.1.prefix
                (paragraph_segment) @neorg.links.location.heading.1
            )
            (
                (link_target_heading2) @neorg.links.location.heading.2.prefix
                (paragraph_segment) @neorg.links.location.heading.2
            )
            (
                (link_target_heading3) @neorg.links.location.heading.3.prefix
                (paragraph_segment) @neorg.links.location.heading.3
            )
            (
                (link_target_heading4) @neorg.links.location.heading.4.prefix
                (paragraph_segment) @neorg.links.location.heading.4
            )
            (
                (link_target_heading5) @neorg.links.location.heading.5.prefix
                (paragraph_segment) @neorg.links.location.heading.5
            )
            (
                (link_target_heading6) @neorg.links.location.heading.6.prefix
                (paragraph_segment) @neorg.links.location.heading.6
            )
        ]
        ("_end") @neorg.links.location.delimiter
    )
)

; Headings
(heading1 (heading1_prefix) @neorg.headings.1.prefix title: (paragraph_segment) @neorg.headings.1.title)
(heading2 (heading2_prefix) @neorg.headings.2.prefix title: (paragraph_segment) @neorg.headings.2.title)
(heading3 (heading3_prefix) @neorg.headings.3.prefix title: (paragraph_segment) @neorg.headings.3.title)
(heading4 (heading4_prefix) @neorg.headings.4.prefix title: (paragraph_segment) @neorg.headings.4.title)
(heading5 (heading5_prefix) @neorg.headings.5.prefix title: (paragraph_segment) @neorg.headings.5.title)
(heading6 (heading6_prefix) @neorg.headings.6.prefix title: (paragraph_segment) @neorg.headings.6.title)

; Display errors
(ERROR) @neorg.error

; Markers
(marker (marker_prefix) @neorg.markers.prefix (paragraph_segment) @neorg.markers.title)

; Definitions
(single_definition (single_definition_prefix) @neorg.definitions.prefix title: (paragraph_segment) @neorg.definitions.title content: [(_) "_paragraph_break"]* @neorg.definitions.content)
(multi_definition (multi_definition_prefix) @neorg.definitions.prefix title: (paragraph_segment) @neorg.definitions.title content: [(_) "_paragraph_break"]* @neorg.definitions.content end: (multi_definition_suffix) @neorg.definitions.suffix)

; Footnotes
(single_footnote (single_footnote_prefix) @neorg.footnotes.prefix title: (paragraph_segment) @neorg.footnotes.title content: [(_) "_paragraph_break"]* @neorg.footnotes.content)
(multi_footnote (multi_footnote_prefix) @neorg.footnotes.prefix title: (paragraph_segment) @neorg.footnotes.title content: [(_) "_paragraph_break"]* @neorg.footnotes.content end: (multi_footnote_suffix) @neorg.footnotes.suffix)

; Escape sequences (\char)
(escape_sequence) @neorg.modifiers.escape

; Todo Items
(todo_item1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix state: (todo_item_undone)    @neorg.todo_items.undone.1    content: (paragraph) @neorg.todo_items.undone.1.content)
(todo_item1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix state: (todo_item_pending)   @neorg.todo_items.pending.1   content: (paragraph) @neorg.todo_items.pending.1.content)
(todo_item1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix state: (todo_item_done)      @neorg.todo_items.done.1      content: (paragraph) @neorg.todo_items.done.1.content)
(todo_item1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix state: (todo_item_on_hold)   @neorg.todo_items.on_hold.1   content: (paragraph) @neorg.todo_items.on_hold.1.content)
(todo_item1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix state: (todo_item_cancelled) @neorg.todo_items.cancelled.1 content: (paragraph) @neorg.todo_items.cancelled.1.content)
(todo_item1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix state: (todo_item_urgent)    @neorg.todo_items.urgent.1    content: (paragraph) @neorg.todo_items.urgent.1.content)
(todo_item1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix state: (todo_item_uncertain) @neorg.todo_items.uncertain.1 content: (paragraph) @neorg.todo_items.uncertain.1.content)
(todo_item1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix state: (todo_item_recurring) @neorg.todo_items.recurring.1 content: (paragraph) @neorg.todo_items.recurring.1.content)

(todo_item2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix state: (todo_item_undone)    @neorg.todo_items.undone.2    content: (paragraph) @neorg.todo_items.undone.2.content)
(todo_item2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix state: (todo_item_pending)   @neorg.todo_items.pending.2   content: (paragraph) @neorg.todo_items.pending.2.content)
(todo_item2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix state: (todo_item_done)      @neorg.todo_items.done.2      content: (paragraph) @neorg.todo_items.done.2.content)
(todo_item2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix state: (todo_item_on_hold)   @neorg.todo_items.on_hold.2   content: (paragraph) @neorg.todo_items.on_hold.2.content)
(todo_item2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix state: (todo_item_cancelled) @neorg.todo_items.cancelled.2 content: (paragraph) @neorg.todo_items.cancelled.2.content)
(todo_item2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix state: (todo_item_urgent)    @neorg.todo_items.urgent.2    content: (paragraph) @neorg.todo_items.urgent.2.content)
(todo_item2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix state: (todo_item_uncertain) @neorg.todo_items.uncertain.2 content: (paragraph) @neorg.todo_items.uncertain.2.content)
(todo_item2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix state: (todo_item_recurring) @neorg.todo_items.recurring.2 content: (paragraph) @neorg.todo_items.recurring.2.content)

(todo_item3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix state: (todo_item_undone)    @neorg.todo_items.undone.3    content: (paragraph) @neorg.todo_items.undone.3.content)
(todo_item3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix state: (todo_item_pending)   @neorg.todo_items.pending.3   content: (paragraph) @neorg.todo_items.pending.3.content)
(todo_item3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix state: (todo_item_done)      @neorg.todo_items.done.3      content: (paragraph) @neorg.todo_items.done.3.content)
(todo_item3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix state: (todo_item_on_hold)   @neorg.todo_items.on_hold.3   content: (paragraph) @neorg.todo_items.on_hold.3.content)
(todo_item3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix state: (todo_item_cancelled) @neorg.todo_items.cancelled.3 content: (paragraph) @neorg.todo_items.cancelled.3.content)
(todo_item3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix state: (todo_item_urgent)    @neorg.todo_items.urgent.3    content: (paragraph) @neorg.todo_items.urgent.3.content)
(todo_item3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix state: (todo_item_uncertain) @neorg.todo_items.uncertain.3 content: (paragraph) @neorg.todo_items.uncertain.3.content)
(todo_item3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix state: (todo_item_recurring) @neorg.todo_items.recurring.3 content: (paragraph) @neorg.todo_items.recurring.3.content)

(todo_item4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix state: (todo_item_undone)    @neorg.todo_items.undone.4    content: (paragraph) @neorg.todo_items.undone.4.content)
(todo_item4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix state: (todo_item_pending)   @neorg.todo_items.pending.4   content: (paragraph) @neorg.todo_items.pending.4.content)
(todo_item4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix state: (todo_item_done)      @neorg.todo_items.done.4      content: (paragraph) @neorg.todo_items.done.4.content)
(todo_item4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix state: (todo_item_on_hold)   @neorg.todo_items.on_hold.4   content: (paragraph) @neorg.todo_items.on_hold.4.content)
(todo_item4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix state: (todo_item_cancelled) @neorg.todo_items.cancelled.4 content: (paragraph) @neorg.todo_items.cancelled.4.content)
(todo_item4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix state: (todo_item_urgent)    @neorg.todo_items.urgent.4    content: (paragraph) @neorg.todo_items.urgent.4.content)
(todo_item4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix state: (todo_item_uncertain) @neorg.todo_items.uncertain.4 content: (paragraph) @neorg.todo_items.uncertain.4.content)
(todo_item4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix state: (todo_item_recurring) @neorg.todo_items.recurring.4 content: (paragraph) @neorg.todo_items.recurring.4.content)

(todo_item5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix state: (todo_item_undone)    @neorg.todo_items.undone.5    content: (paragraph) @neorg.todo_items.undone.5.content)
(todo_item5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix state: (todo_item_pending)   @neorg.todo_items.pending.5   content: (paragraph) @neorg.todo_items.pending.5.content)
(todo_item5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix state: (todo_item_done)      @neorg.todo_items.done.5      content: (paragraph) @neorg.todo_items.done.5.content)
(todo_item5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix state: (todo_item_on_hold)   @neorg.todo_items.on_hold.5   content: (paragraph) @neorg.todo_items.on_hold.5.content)
(todo_item5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix state: (todo_item_cancelled) @neorg.todo_items.cancelled.5 content: (paragraph) @neorg.todo_items.cancelled.5.content)
(todo_item5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix state: (todo_item_urgent)    @neorg.todo_items.urgent.5    content: (paragraph) @neorg.todo_items.urgent.5.content)
(todo_item5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix state: (todo_item_uncertain) @neorg.todo_items.uncertain.5 content: (paragraph) @neorg.todo_items.uncertain.5.content)
(todo_item5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix state: (todo_item_recurring) @neorg.todo_items.recurring.5 content: (paragraph) @neorg.todo_items.recurring.5.content)

(todo_item6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix state: (todo_item_undone)    @neorg.todo_items.undone.6    content: (paragraph) @neorg.todo_items.undone.6.content)
(todo_item6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix state: (todo_item_pending)   @neorg.todo_items.pending.6   content: (paragraph) @neorg.todo_items.pending.6.content)
(todo_item6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix state: (todo_item_done)      @neorg.todo_items.done.6      content: (paragraph) @neorg.todo_items.done.6.content)
(todo_item6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix state: (todo_item_on_hold)   @neorg.todo_items.on_hold.6   content: (paragraph) @neorg.todo_items.on_hold.6.content)
(todo_item6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix state: (todo_item_cancelled) @neorg.todo_items.cancelled.6 content: (paragraph) @neorg.todo_items.cancelled.6.content)
(todo_item6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix state: (todo_item_urgent)    @neorg.todo_items.urgent.6    content: (paragraph) @neorg.todo_items.urgent.6.content)
(todo_item6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix state: (todo_item_uncertain) @neorg.todo_items.uncertain.6 content: (paragraph) @neorg.todo_items.uncertain.6.content)
(todo_item6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix state: (todo_item_recurring) @neorg.todo_items.recurring.6 content: (paragraph) @neorg.todo_items.recurring.6.content)


; Unordered lists
(unordered_list1 (unordered_list1_prefix) @neorg.lists.unordered.1.prefix content: (paragraph) @neorg.lists.unordered.1.content)
(unordered_list2 (unordered_list2_prefix) @neorg.lists.unordered.2.prefix content: (paragraph) @neorg.lists.unordered.2.content)
(unordered_list3 (unordered_list3_prefix) @neorg.lists.unordered.3.prefix content: (paragraph) @neorg.lists.unordered.3.content)
(unordered_list4 (unordered_list4_prefix) @neorg.lists.unordered.4.prefix content: (paragraph) @neorg.lists.unordered.4.content)
(unordered_list5 (unordered_list5_prefix) @neorg.lists.unordered.5.prefix content: (paragraph) @neorg.lists.unordered.5.content)
(unordered_list6 (unordered_list6_prefix) @neorg.lists.unordered.6.prefix content: (paragraph) @neorg.lists.unordered.6.content)

; Ordered lists
(ordered_list1 (ordered_list1_prefix) @neorg.lists.ordered.1.prefix content: (paragraph) @neorg.lists.ordered.1.content)
(ordered_list2 (ordered_list2_prefix) @neorg.lists.ordered.2.prefix content: (paragraph) @neorg.lists.ordered.2.content)
(ordered_list3 (ordered_list3_prefix) @neorg.lists.ordered.3.prefix content: (paragraph) @neorg.lists.ordered.3.content)
(ordered_list4 (ordered_list4_prefix) @neorg.lists.ordered.4.prefix content: (paragraph) @neorg.lists.ordered.4.content)
(ordered_list5 (ordered_list5_prefix) @neorg.lists.ordered.5.prefix content: (paragraph) @neorg.lists.ordered.5.content)
(ordered_list6 (ordered_list6_prefix) @neorg.lists.ordered.6.prefix content: (paragraph) @neorg.lists.ordered.6.content)

; Unordered links (DEPRECATED)
; (unordered_link1 (unordered_link1_prefix) location: (link) )
; (unordered_link2 (unordered_link2_prefix) location: (link) )
; (unordered_link3 (unordered_link3_prefix) location: (link) )
; (unordered_link4 (unordered_link4_prefix) location: (link) )
; (unordered_link5 (unordered_link5_prefix) location: (link) )
; (unordered_link6 (unordered_link6_prefix) location: (link) )

; Ordered links (DEPRECATED)
; (ordered_link1 (ordered_link1_prefix) location: (link) )
; (ordered_link2 (ordered_link2_prefix) location: (link) )
; (ordered_link3 (ordered_link3_prefix) location: (link) )
; (ordered_link4 (ordered_link4_prefix) location: (link) )
; (ordered_link5 (ordered_link5_prefix) location: (link) )
; (ordered_link6 (ordered_link6_prefix) location: (link) )

; Quotes
(quote1 (quote1_prefix) @neorg.quotes.1.prefix content: (paragraph_segment) @neorg.quotes.1.content)
(quote2 (quote2_prefix) @neorg.quotes.2.prefix content: (paragraph_segment) @neorg.quotes.2.content)
(quote3 (quote3_prefix) @neorg.quotes.3.prefix content: (paragraph_segment) @neorg.quotes.3.content)
(quote4 (quote4_prefix) @neorg.quotes.4.prefix content: (paragraph_segment) @neorg.quotes.4.content)
(quote5 (quote5_prefix) @neorg.quotes.5.prefix content: (paragraph_segment) @neorg.quotes.5.content)
(quote6 (quote6_prefix) @neorg.quotes.6.prefix content: (paragraph_segment) @neorg.quotes.6.content)

; Insertion
(insertion (insertion_prefix) @neorg.insertions.prefix item: (lowercase_word) @neorg.insertions.variable.name parameters: (paragraph_segment)? @neorg.insertions.variable.value)
(insertion (insertion_prefix) @neorg.insertions.prefix item: (capitalized_word) @neorg.insertions.item parameters: (paragraph_segment)? @neorg.insertions.parameters)

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
(variable ["_open" "_close"] @neorg.markup.variable.delimiter) @neorg.markup.variable

(superscript (subscript) @neorg.error (#set! priority 300))
(subscript (superscript) @neorg.error (#set! priority 300))

; Comments
(inline_comment) @comment

; Conceals
(
    [
        "_open"
        "_close"
        "_trailing_modifier"
        (link_modifier)
    ] @conceal
    (#set! conceal "")
)

(
    [
        (link
            (_
                [
                    "_begin"
                    type: (_)
                    "_end"
                ] @conceal
            )
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
        (_
            [
                "_begin"
                "_end"
            ] @conceal
            (#has-parent? "anchor_declaration" "anchor_definition")
        )
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
