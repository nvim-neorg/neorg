(ranged_tag
    ("_prefix") @NeorgTagBegin
	name: (tag_name
        [(tag_name_element) @NeorgTagNameWord ("_delimiter") @NeorgTagNameDelimiter]+) @NeorgTagName
	(tag_parameters parameter: (tag_param)+ @NeorgTagParameter)? @NeorgTagParameters
	content: (ranged_tag_content)?
	(ranged_tag_end ("_prefix") @NeorgTagEnd ("_name") @NeorgTagNameWord)?) @NeorgTag

(ranged_verbatim_tag
    ("_prefix") @NeorgVerbatimTagBegin
	name: (tag_name
        [(tag_name_element) @NeorgVerbatimTagNameWord ("_delimiter") @NeorgVerbatimTagNameDelimiter]+) @NeorgVerbatimTagName
	(tag_parameters parameter: (tag_param)+ @NeorgVerbatimTagParameter)? @NeorgVerbatimTagParameters
	content: (ranged_verbatim_tag_content)?
	(ranged_verbatim_tag_end ("_prefix") @NeorgVerbatimTagEnd ("_name") @NeorgVerbatimTagNameWord)?) @NeorgVerbatimTag

(carryover_tag_set
    (carryover_tag
        ("_prefix" @NeorgCarryoverTagBegin)
        name:
            (tag_name
                [
                    (tag_name_element) @NeorgCarryoverTagNameWord
                    ("_delimiter") @NeorgCarryoverTagNameDelimiter
                ]
            ) @NeorgCarryoverTagName
        (tag_parameters
            parameter: (tag_param) @NeorgCarryoverTagParameter
        )? @NeorgCarryoverTagParameters
    ) @NeorgCarryoverTag

	target: (_) @NeorgCarryoverTagTarget
)

; Trailing Modifier
("_trailing_modifier") @NeorgTrailingModifier

; Link Modifier
(link_modifier) @NeorgLinkModifier

; Links
(link
    (link_location
        ("_begin") @NeorgLinkLocationDelimiter
        [
            ("_begin") @NeorgLinkFileDelimiter
            file: (link_file_text) @NeorgLinkFile
            ("_end") @NeorgLinkFileDelimiter
            (
                (link_target_url) ; Doesn't require a highlight since it's a 0-width node
                (paragraph) @NeorgLinkLocationURL
            )
            (
                (link_target_generic) @NeorgLinkLocationGenericPrefix
                (paragraph) @NeorgLinkLocationGeneric
            )
            (
                (link_target_external_file) @NeorgLinkLocationExternalFilePrefix
                (paragraph) @NeorgLinkLocationExternalFile
            )
            (
                (link_target_marker) @NeorgLinkLocationMarkerPrefix
                (paragraph) @NeorgLinkLocationMarker
            )
            (
                (link_target_definition) @NeorgLinkLocationDefinitionPrefix
                (paragraph) @NeorgLinkLocationDefinition
            )
            (
                (link_target_footnote) @NeorgLinkLocationFootnotePrefix
                (paragraph) @NeorgLinkLocationFootnote
            )
            (
                (link_target_heading1) @NeorgLinkLocationHeading1Prefix
                (paragraph) @NeorgLinkLocationHeading1
            )
            (
                (link_target_heading2) @NeorgLinkLocationHeading2Prefix
                (paragraph) @NeorgLinkLocationHeading2
            )
            (
                (link_target_heading3) @NeorgLinkLocationHeading3Prefix
                (paragraph) @NeorgLinkLocationHeading3
            )
            (
                (link_target_heading4) @NeorgLinkLocationHeading4Prefix
                (paragraph) @NeorgLinkLocationHeading4
            )
            (
                (link_target_heading5) @NeorgLinkLocationHeading5Prefix
                (paragraph) @NeorgLinkLocationHeading5
            )
            (
                (link_target_heading6) @NeorgLinkLocationHeading6Prefix
                (paragraph) @NeorgLinkLocationHeading6
            )
        ]
        ("_end") @NeorgLinkLocationDelimiter
    )
    (link_description
        ("_begin") @NeorgLinkTextDelimiter
        text: (paragraph) @NeorgLinkText
        ("_end") @NeorgLinkTextDelimiter
    )?
) @NeorgLink

; Anchors
(anchor_declaration
    (link_description
        ("_begin") @NeorgAnchorDeclarationDelimiter
        text: (paragraph) @NeorgAnchorDeclarationText
        ("_end") @NeorgAnchorDeclarationDelimiter
    )
) @NeorgAnchor

(anchor_definition
    (link_description
        ("_begin") @NeorgAnchorDeclarationDelimiter
        text: (paragraph) @NeorgAnchorDeclarationText
        ("_end") @NeorgAnchorDeclarationDelimiter
    )
    (link_location
        ("_begin") @NeorgAnchorDefinitionDelimiter
        [
            ("_begin") @NeorgLinkFileDelimiter
            file: (link_file_text) @NeorgLinkFile
            ("_end") @NeorgLinkFileDelimiter
            (
                (link_target_url) ; Doesn't require a highlight since it's a 0-width node
                (paragraph) @NeorgLinkLocationURL
            )
            (
                (link_target_generic) @NeorgLinkLocationGenericPrefix
                (paragraph) @NeorgLinkLocationGeneric
            )
            (
                (link_target_external_file) @NeorgLinkLocationExternalFilePrefix
                (paragraph) @NeorgLinkLocationExternalFile
            )
            (
                (link_target_marker) @NeorgLinkLocationMarkerPrefix
                (paragraph) @NeorgLinkLocationMarker
            )
            (
                (link_target_definition) @NeorgLinkLocationDefinitionPrefix
                (paragraph) @NeorgLinkLocationDefinition
            )
            (
                (link_target_footnote) @NeorgLinkLocationFootnotePrefix
                (paragraph) @NeorgLinkLocationFootnote
            )
            (
                (link_target_heading1) @NeorgLinkLocationHeading1Prefix
                (paragraph) @NeorgLinkLocationHeading1
            )
            (
                (link_target_heading2) @NeorgLinkLocationHeading2Prefix
                (paragraph) @NeorgLinkLocationHeading2
            )
            (
                (link_target_heading3) @NeorgLinkLocationHeading3Prefix
                (paragraph) @NeorgLinkLocationHeading3
            )
            (
                (link_target_heading4) @NeorgLinkLocationHeading4Prefix
                (paragraph) @NeorgLinkLocationHeading4
            )
            (
                (link_target_heading5) @NeorgLinkLocationHeading5Prefix
                (paragraph) @NeorgLinkLocationHeading5
            )
            (
                (link_target_heading6) @NeorgLinkLocationHeading6Prefix
                (paragraph) @NeorgLinkLocationHeading6
            )
        ]
        ("_end") @NeorgAnchorDefinitionDelimiter
    )?
) @NeorgAnchor

; Headings
(heading1 (heading1_prefix) @NeorgHeading1Prefix title: (paragraph_segment) @NeorgHeading1Title) @NeorgHeading1
(heading2 (heading2_prefix) @NeorgHeading2Prefix title: (paragraph_segment) @NeorgHeading2Title) @NeorgHeading2
(heading3 (heading3_prefix) @NeorgHeading3Prefix title: (paragraph_segment) @NeorgHeading3Title) @NeorgHeading3
(heading4 (heading4_prefix) @NeorgHeading4Prefix title: (paragraph_segment) @NeorgHeading4Title) @NeorgHeading4
(heading5 (heading5_prefix) @NeorgHeading5Prefix title: (paragraph_segment) @NeorgHeading5Title) @NeorgHeading5
(heading6 (heading6_prefix) @NeorgHeading6Prefix title: (paragraph_segment) @NeorgHeading6Title) @NeorgHeading6

; Display errors
(ERROR) @NeorgError

; Markers
(marker (marker_prefix) @NeorgMarkerPrefix (paragraph_segment) @NeorgMarkerTitle)

; Definitions
(single_definition (single_definition_prefix) @NeorgDefinition title: (paragraph_segment) @NeorgDefinitionTitle definition: [(_) "_paragraph_break"]* @NeorgDefinitionContent)
(multi_definition (multi_definition_prefix) @NeorgDefinition title: (paragraph_segment) @NeorgDefinitionTitle content: [(_) "_paragraph_break"]* @NeorgDefinitionContent end: (multi_definition_suffix) @NeorgDefinitionEnd)

; Footnotes
(single_footnote (single_footnote_prefix) @NeorgFootnote title: (paragraph_segment) @NeorgFootnoteTitle content: [(_) "_paragraph_break"]* @NeorgFootnoteContent)
(multi_footnote (multi_footnote_prefix) @NeorgFootnote title: (paragraph_segment) @NeorgFootnoteTitle content: [(_) "_paragraph_break"]* @NeorgFootnoteContent end: (multi_footnote_suffix) @NeorgFootnoteEnd)

; Escape sequences (\char)
(escape_sequence) @NeorgEscapeSequence

; Todo Items
(todo_item1
	(unordered_list1_prefix) @NeorgTodoItem1
	state:
		[
			(todo_item_undone) @NeorgTodoItem1Undone
			(todo_item_pending) @NeorgTodoItem1Pending
			(todo_item_done) @NeorgTodoItem1Done
                        (todo_item_on_hold) @NeorgTodoItem1OnHold
                        (todo_item_cancelled) @NeorgTodoItem1Cancelled
                        (todo_item_urgent) @NeorgTodoItem1Urgent
                        (todo_item_uncertain) @NeorgTodoItem1Uncertain
                        (todo_item_recurring) @NeorgTodoItem1Recurring
		]
	content:
		(paragraph) @NeorgTodoItem1Content)

(todo_item2
	(unordered_list2_prefix) @NeorgTodoItem2
	state:
		[
			(todo_item_undone) @NeorgTodoItem2Undone
			(todo_item_pending) @NeorgTodoItem2Pending
			(todo_item_done) @NeorgTodoItem2Done
            (todo_item_on_hold) @NeorgTodoItem2OnHold
            (todo_item_cancelled) @NeorgTodoItem2Cancelled
            (todo_item_urgent) @NeorgTodoItem2Urgent
            (todo_item_uncertain) @NeorgTodoItem2Uncertain
            (todo_item_recurring) @NeorgTodoItem2Recurring
		]
	content:
		(paragraph) @NeorgTodoItem2Content)

(todo_item3
	(unordered_list3_prefix) @NeorgTodoItem3
	state:
		[
			(todo_item_undone) @NeorgTodoItem3Undone
			(todo_item_pending) @NeorgTodoItem3Pending
			(todo_item_done) @NeorgTodoItem3Done
                        (todo_item_on_hold) @NeorgTodoItem3OnHold
                        (todo_item_cancelled) @NeorgTodoItem3Cancelled
                        (todo_item_urgent) @NeorgTodoItem3Urgent
                        (todo_item_uncertain) @NeorgTodoItem3Uncertain
                        (todo_item_recurring) @NeorgTodoItem3Recurring
		]
	content:
		(paragraph) @NeorgTodoItem3Content)

(todo_item4
	(unordered_list4_prefix) @NeorgTodoItem4
	state:
		[
			(todo_item_undone) @NeorgTodoItem4Undone
			(todo_item_pending) @NeorgTodoItem4Pending
			(todo_item_done) @NeorgTodoItem4Done
                        (todo_item_on_hold) @NeorgTodoItem4OnHold
                        (todo_item_cancelled) @NeorgTodoItem4Cancelled
                        (todo_item_urgent) @NeorgTodoItem4Urgent
                        (todo_item_uncertain) @NeorgTodoItem4Uncertain
                        (todo_item_recurring) @NeorgTodoItem4Recurring
		]
	content:
		(paragraph) @NeorgTodoItem4Content)

(todo_item5
	(unordered_list5_prefix) @NeorgTodoItem5
	state:
		[
			(todo_item_undone) @NeorgTodoItem5Undone
			(todo_item_pending) @NeorgTodoItem5Pending
			(todo_item_done) @NeorgTodoItem5Done
                        (todo_item_on_hold) @NeorgTodoItem5OnHold
                        (todo_item_cancelled) @NeorgTodoItem5Cancelled
                        (todo_item_urgent) @NeorgTodoItem5Urgent
                        (todo_item_uncertain) @NeorgTodoItem5Uncertain
                        (todo_item_recurring) @NeorgTodoItem5Recurring
		]
	content:
		(paragraph) @NeorgTodoItem5Content)

(todo_item6
	(unordered_list6_prefix) @NeorgTodoItem6
	state:
		[
			(todo_item_undone) @NeorgTodoItem6Undone
			(todo_item_pending) @NeorgTodoItem6Pending
			(todo_item_done) @NeorgTodoItem6Done
                        (todo_item_on_hold) @NeorgTodoItem6OnHold
                        (todo_item_cancelled) @NeorgTodoItem6Cancelled
                        (todo_item_urgent) @NeorgTodoItem6Urgent
                        (todo_item_uncertain) @NeorgTodoItem6Uncertain
                        (todo_item_recurring) @NeorgTodoItem6Recurring
		]
	content:
		(paragraph) @NeorgTodoItem6Content)

; Unordered lists
(unordered_list1 (unordered_list1_prefix) @NeorgUnorderedList1 content: (paragraph) @NeorgUnorderedList1Content)
(unordered_list2 (unordered_list2_prefix) @NeorgUnorderedList2 content: (paragraph) @NeorgUnorderedList2Content)
(unordered_list3 (unordered_list3_prefix) @NeorgUnorderedList3 content: (paragraph) @NeorgUnorderedList3Content)
(unordered_list4 (unordered_list4_prefix) @NeorgUnorderedList4 content: (paragraph) @NeorgUnorderedList4Content)
(unordered_list5 (unordered_list5_prefix) @NeorgUnorderedList5 content: (paragraph) @NeorgUnorderedList5Content)
(unordered_list6 (unordered_list6_prefix) @NeorgUnorderedList6 content: (paragraph) @NeorgUnorderedList6Content)

; Ordered lists
(ordered_list1 (ordered_list1_prefix) @NeorgOrderedList1 content: (paragraph) @NeorgOrderedList1Content)
(ordered_list2 (ordered_list2_prefix) @NeorgOrderedList2 content: (paragraph) @NeorgOrderedList2Content)
(ordered_list3 (ordered_list3_prefix) @NeorgOrderedList3 content: (paragraph) @NeorgOrderedList3Content)
(ordered_list4 (ordered_list4_prefix) @NeorgOrderedList4 content: (paragraph) @NeorgOrderedList4Content)
(ordered_list5 (ordered_list5_prefix) @NeorgOrderedList5 content: (paragraph) @NeorgOrderedList5Content)
(ordered_list6 (ordered_list6_prefix) @NeorgOrderedList6 content: (paragraph) @NeorgOrderedList6Content)

; Quotes
(quote1 (quote1_prefix) @NeorgQuote1 content: (paragraph) @NeorgQuote1Content)
(quote2 (quote2_prefix) @NeorgQuote2 content: (paragraph) @NeorgQuote2Content)
(quote3 (quote3_prefix) @NeorgQuote3 content: (paragraph) @NeorgQuote3Content)
(quote4 (quote4_prefix) @NeorgQuote4 content: (paragraph) @NeorgQuote4Content)
(quote5 (quote5_prefix) @NeorgQuote5 content: (paragraph) @NeorgQuote5Content)
(quote6 (quote6_prefix) @NeorgQuote6 content: (paragraph) @NeorgQuote6Content)

; Insertion
(insertion (insertion_prefix) @NeorgInsertionPrefix item: (lowercase_word) @NeorgInsertionVariable parameters: (paragraph_segment)? @NeorgInsertionVariableValue) @NeorgInsertion
(insertion (insertion_prefix) @NeorgInsertionPrefix item: (capitalized_word) @NeorgInsertionItem parameters: (paragraph_segment)? @NeorgInsertionParameters) @NeorgInsertion

; Paragraph Delimiters
(strong_paragraph_delimiter) @NeorgStrongParagraphDelimiter
(weak_paragraph_delimiter) @NeorgWeakParagraphDelimiter
(horizontal_line) @NeorgHorizontalLine

; Markup
(bold ["_open" "_close"] @NeorgMarkupBoldDelimiter) @NeorgMarkupBold
(italic ["_open" "_close"] @NeorgMarkupItalicDelimiter) @NeorgMarkupItalic
(strikethrough ["_open" "_close"] @NeorgMarkupStrikethroughDelimiter) @NeorgMarkupStrikethrough
(underline ["_open" "_close"] @NeorgMarkupUnderlineDelimiter) @NeorgMarkupUnderline
(spoiler ["_open" "_close"] @NeorgMarkupSpoilerDelimiter) @NeorgMarkupSpoiler
(verbatim ["_open" "_close"] @NeorgMarkupVerbatimDelimiter) @NeorgMarkupVerbatim
(superscript ["_open" "_close"] @NeorgMarkupSuperscriptDelimiter) @NeorgMarkupSuperscript
(subscript ["_open" "_close"] @NeorgMarkupSubscriptDelimiter) @NeorgMarkupSubscript
(inline_comment ["_open" "_close"] @NeorgMarkupInlineCommentDelimiter) @NeorgMarkupInlineComment
(inline_math ["_open" "_close"] @NeorgMarkupMathDelimiter) @NeorgMarkupMath
(variable ["_open" "_close"] @NeorgMarkupVariableDelimiter) @NeorgMarkupVariable

(superscript (subscript) @NeorgError (#set! priority 300))
(subscript (superscript) @NeorgError (#set! priority 300))

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
