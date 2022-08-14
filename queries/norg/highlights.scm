(ranged_tag ("_prefix") @NeorgTagBegin
	name: (tag_name [(tag_name_element) @NeorgTagNameWord ("_delimiter") @NeorgTagNameDelimiter]) @NeorgTagName
	(tag_parameters parameter: (tag_param) @NeorgTagParameter)? @NeorgTagParameters
	content: (ranged_tag_content)?
	(ranged_tag_end ("_prefix") @NeorgTagEnd ("_name") @NeorgTagNameWord)) @NeorgTag

; TODO: Make the content of @comment darker

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
            (
                ("_begin") @NeorgLinkFileDelimiter
                file: (link_file_text) @NeorgLinkFile
                ("_end") @NeorgLinkFileDelimiter
            )
            (
                (link_target_url) ; Doesn't require a highlight since it's a 0-width node
                (paragraph_segment) @NeorgLinkLocationURL
            )
            (
                (link_target_generic) @NeorgLinkLocationGenericPrefix
                (paragraph_segment) @NeorgLinkLocationGeneric
            )
            (
                (link_target_external_file) @NeorgLinkLocationExternalFilePrefix
                (paragraph_segment) @NeorgLinkLocationExternalFile
            )
            (
                (link_target_marker) @NeorgLinkLocationMarkerPrefix
                (paragraph_segment) @NeorgLinkLocationMarker
            )
            (
                (link_target_definition) @NeorgLinkLocationDefinitionPrefix
                (paragraph_segment) @NeorgLinkLocationDefinition
            )
            (
                (link_target_footnote) @NeorgLinkLocationFootnotePrefix
                (paragraph_segment) @NeorgLinkLocationFootnote
            )
            (
                (link_target_heading1) @NeorgLinkLocationHeading1Prefix
                (paragraph_segment) @NeorgLinkLocationHeading1
            )
            (
                (link_target_heading2) @NeorgLinkLocationHeading2Prefix
                (paragraph_segment) @NeorgLinkLocationHeading2
            )
            (
                (link_target_heading3) @NeorgLinkLocationHeading3Prefix
                (paragraph_segment) @NeorgLinkLocationHeading3
            )
            (
                (link_target_heading4) @NeorgLinkLocationHeading4Prefix
                (paragraph_segment) @NeorgLinkLocationHeading4
            )
            (
                (link_target_heading5) @NeorgLinkLocationHeading5Prefix
                (paragraph_segment) @NeorgLinkLocationHeading5
            )
            (
                (link_target_heading6) @NeorgLinkLocationHeading6Prefix
                (paragraph_segment) @NeorgLinkLocationHeading6
            )
        ]
        ("_end") @NeorgLinkLocationDelimiter
    )
    (link_description
        ("_begin") @NeorgLinkTextDelimiter
        text: (paragraph_segment) @NeorgLinkText
        ("_end") @NeorgLinkTextDelimiter
    )?
) @NeorgLink

; Anchors
(anchor_declaration
    (link_description
        ("_begin") @NeorgAnchorDeclarationDelimiter
        text: (paragraph_segment) @NeorgAnchorDeclarationText
        ("_end") @NeorgAnchorDeclarationDelimiter
    )
) @NeorgAnchor

(anchor_definition
    (link_description
        ("_begin") @NeorgAnchorDeclarationDelimiter
        text: (paragraph_segment) @NeorgAnchorDeclarationText
        ("_end") @NeorgAnchorDeclarationDelimiter
    )
    (link_location
        ("_begin") @NeorgAnchorDefinitionDelimiter
        [
            (
                ("_begin") @NeorgLinkFileDelimiter
                file: (link_file_text) @NeorgLinkFile
                ("_end") @NeorgLinkFileDelimiter
            )
            (
                (link_target_url) ; Doesn't require a highlight since it's a 0-width node
                (paragraph_segment) @NeorgLinkLocationURL
            )
            (
                (link_target_generic) @NeorgLinkLocationGenericPrefix
                (paragraph_segment) @NeorgLinkLocationGeneric
            )
            (
                (link_target_external_file) @NeorgLinkLocationExternalFilePrefix
                (paragraph_segment) @NeorgLinkLocationExternalFile
            )
            (
                (link_target_marker) @NeorgLinkLocationMarkerPrefix
                (paragraph_segment) @NeorgLinkLocationMarker
            )
            (
                (link_target_definition) @NeorgLinkLocationDefinitionPrefix
                (paragraph_segment) @NeorgLinkLocationDefinition
            )
            (
                (link_target_footnote) @NeorgLinkLocationFootnotePrefix
                (paragraph_segment) @NeorgLinkLocationFootnote
            )
            (
                (link_target_heading1) @NeorgLinkLocationHeading1Prefix
                (paragraph_segment) @NeorgLinkLocationHeading1
            )
            (
                (link_target_heading2) @NeorgLinkLocationHeading2Prefix
                (paragraph_segment) @NeorgLinkLocationHeading2
            )
            (
                (link_target_heading3) @NeorgLinkLocationHeading3Prefix
                (paragraph_segment) @NeorgLinkLocationHeading3
            )
            (
                (link_target_heading4) @NeorgLinkLocationHeading4Prefix
                (paragraph_segment) @NeorgLinkLocationHeading4
            )
            (
                (link_target_heading5) @NeorgLinkLocationHeading5Prefix
                (paragraph_segment) @NeorgLinkLocationHeading5
            )
            (
                (link_target_heading6) @NeorgLinkLocationHeading6Prefix
                (paragraph_segment) @NeorgLinkLocationHeading6
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
(todo_item1 (unordered_list1_prefix) @NeorgTodoItem1)
(todo_item1 state: (todo_item_undone) @NeorgTodoItem1Undone content: (paragraph) @NeorgTodoItem1UndoneContent)
(todo_item1 state: (todo_item_pending) @NeorgTodoItem1Pending content: (paragraph) @NeorgTodoItem1PendingContent)
(todo_item1 state: (todo_item_done) @NeorgTodoItem1Done content: (paragraph) @NeorgTodoItem1DoneContent)
(todo_item1 state: (todo_item_on_hold) @NeorgTodoItem1OnHold content: (paragraph) @NeorgTodoItem1OnHoldContent)
(todo_item1 state: (todo_item_cancelled) @NeorgTodoItem1Cancelled content: (paragraph) @NeorgTodoItem1CancelledContent)
(todo_item1 state: (todo_item_urgent) @NeorgTodoItem1Urgent content: (paragraph) @NeorgTodoItem1UrgentContent)
(todo_item1 state: (todo_item_uncertain) @NeorgTodoItem1Uncertain content: (paragraph) @NeorgTodoItem1UncertainContent)
(todo_item1 state: (todo_item_recurring) @NeorgTodoItem1Recurring content: (paragraph) @NeorgTodoItem1RecurringContent)

(todo_item2 (unordered_list2_prefix) @NeorgTodoItem2)
(todo_item2 state: (todo_item_undone) @NeorgTodoItem2Undone content: (paragraph) @NeorgTodoItem2UndoneContent)
(todo_item2 state: (todo_item_pending) @NeorgTodoItem2Pending content: (paragraph) @NeorgTodoItem2PendingContent)
(todo_item2 state: (todo_item_done) @NeorgTodoItem2Done content: (paragraph) @NeorgTodoItem2DoneContent)
(todo_item2 state: (todo_item_on_hold) @NeorgTodoItem2OnHold content: (paragraph) @NeorgTodoItem2OnHoldContent)
(todo_item2 state: (todo_item_cancelled) @NeorgTodoItem2Cancelled content: (paragraph) @NeorgTodoItem2CancelledContent)
(todo_item2 state: (todo_item_urgent) @NeorgTodoItem2Urgent content: (paragraph) @NeorgTodoItem2UrgentContent)
(todo_item2 state: (todo_item_uncertain) @NeorgTodoItem2Uncertain content: (paragraph) @NeorgTodoItem2UncertainContent)
(todo_item2 state: (todo_item_recurring) @NeorgTodoItem2Recurring content: (paragraph) @NeorgTodoItem2RecurringContent)

(todo_item3 (unordered_list3_prefix) @NeorgTodoItem3)
(todo_item3 state: (todo_item_undone) @NeorgTodoItem3Undone content: (paragraph) @NeorgTodoItem3UndoneContent)
(todo_item3 state: (todo_item_pending) @NeorgTodoItem3Pending content: (paragraph) @NeorgTodoItem3PendingContent)
(todo_item3 state: (todo_item_done) @NeorgTodoItem3Done content: (paragraph) @NeorgTodoItem3DoneContent)
(todo_item3 state: (todo_item_on_hold) @NeorgTodoItem3OnHold content: (paragraph) @NeorgTodoItem3OnHoldContent)
(todo_item3 state: (todo_item_cancelled) @NeorgTodoItem3Cancelled content: (paragraph) @NeorgTodoItem3CancelledContent)
(todo_item3 state: (todo_item_urgent) @NeorgTodoItem3Urgent content: (paragraph) @NeorgTodoItem3UrgentContent)
(todo_item3 state: (todo_item_uncertain) @NeorgTodoItem3Uncertain content: (paragraph) @NeorgTodoItem3UncertainContent)
(todo_item3 state: (todo_item_recurring) @NeorgTodoItem3Recurring content: (paragraph) @NeorgTodoItem3RecurringContent)

(todo_item4 (unordered_list4_prefix) @NeorgTodoItem4)
(todo_item4 state: (todo_item_undone) @NeorgTodoItem4Undone content: (paragraph) @NeorgTodoItem4UndoneContent)
(todo_item4 state: (todo_item_pending) @NeorgTodoItem4Pending content: (paragraph) @NeorgTodoItem4PendingContent)
(todo_item4 state: (todo_item_done) @NeorgTodoItem4Done content: (paragraph) @NeorgTodoItem4DoneContent)
(todo_item4 state: (todo_item_on_hold) @NeorgTodoItem4OnHold content: (paragraph) @NeorgTodoItem4OnHoldContent)
(todo_item4 state: (todo_item_cancelled) @NeorgTodoItem4Cancelled content: (paragraph) @NeorgTodoItem4CancelledContent)
(todo_item4 state: (todo_item_urgent) @NeorgTodoItem4Urgent content: (paragraph) @NeorgTodoItem4UrgentContent)
(todo_item4 state: (todo_item_uncertain) @NeorgTodoItem4Uncertain content: (paragraph) @NeorgTodoItem4UncertainContent)
(todo_item4 state: (todo_item_recurring) @NeorgTodoItem4Recurring content: (paragraph) @NeorgTodoItem4RecurringContent)

(todo_item5 (unordered_list5_prefix) @NeorgTodoItem5)
(todo_item5 state: (todo_item_undone) @NeorgTodoItem5Undone content: (paragraph) @NeorgTodoItem5UndoneContent)
(todo_item5 state: (todo_item_pending) @NeorgTodoItem5Pending content: (paragraph) @NeorgTodoItem5PendingContent)
(todo_item5 state: (todo_item_done) @NeorgTodoItem5Done content: (paragraph) @NeorgTodoItem5DoneContent)
(todo_item5 state: (todo_item_on_hold) @NeorgTodoItem5OnHold content: (paragraph) @NeorgTodoItem5OnHoldContent)
(todo_item5 state: (todo_item_cancelled) @NeorgTodoItem5Cancelled content: (paragraph) @NeorgTodoItem5CancelledContent)
(todo_item5 state: (todo_item_urgent) @NeorgTodoItem5Urgent content: (paragraph) @NeorgTodoItem5UrgentContent)
(todo_item5 state: (todo_item_uncertain) @NeorgTodoItem5Uncertain content: (paragraph) @NeorgTodoItem5UncertainContent)
(todo_item5 state: (todo_item_recurring) @NeorgTodoItem5Recurring content: (paragraph) @NeorgTodoItem5RecurringContent)

(todo_item6 (unordered_list6_prefix) @NeorgTodoItem6)
(todo_item6 state: (todo_item_undone) @NeorgTodoItem6Undone content: (paragraph) @NeorgTodoItem6UndoneContent)
(todo_item6 state: (todo_item_pending) @NeorgTodoItem6Pending content: (paragraph) @NeorgTodoItem6PendingContent)
(todo_item6 state: (todo_item_done) @NeorgTodoItem6Done content: (paragraph) @NeorgTodoItem6DoneContent)
(todo_item6 state: (todo_item_on_hold) @NeorgTodoItem6OnHold content: (paragraph) @NeorgTodoItem6OnHoldContent)
(todo_item6 state: (todo_item_cancelled) @NeorgTodoItem6Cancelled content: (paragraph) @NeorgTodoItem6CancelledContent)
(todo_item6 state: (todo_item_urgent) @NeorgTodoItem6Urgent content: (paragraph) @NeorgTodoItem6UrgentContent)
(todo_item6 state: (todo_item_uncertain) @NeorgTodoItem6Uncertain content: (paragraph) @NeorgTodoItem6UncertainContent)
(todo_item6 state: (todo_item_recurring) @NeorgTodoItem6Recurring content: (paragraph) @NeorgTodoItem6RecurringContent)

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

; Unordered links
(unordered_link1 (unordered_link1_prefix) @NeorgUnorderedLink1 location: (link) @NeorgUnorderedLink1Location)
(unordered_link2 (unordered_link2_prefix) @NeorgUnorderedLink2 location: (link) @NeorgUnorderedLink2Location)
(unordered_link3 (unordered_link3_prefix) @NeorgUnorderedLink3 location: (link) @NeorgUnorderedLink3Location)
(unordered_link4 (unordered_link4_prefix) @NeorgUnorderedLink4 location: (link) @NeorgUnorderedLink4Location)
(unordered_link5 (unordered_link5_prefix) @NeorgUnorderedLink5 location: (link) @NeorgUnorderedLink5Location)
(unordered_link6 (unordered_link6_prefix) @NeorgUnorderedLink6 location: (link) @NeorgUnorderedLink6Location)

; Ordered links
(ordered_link1 (ordered_link1_prefix) @NeorgOrderedLink1 location: (link) @NeorgOrderedLink1Location)
(ordered_link2 (ordered_link2_prefix) @NeorgOrderedLink2 location: (link) @NeorgOrderedLink2Location)
(ordered_link3 (ordered_link3_prefix) @NeorgOrderedLink3 location: (link) @NeorgOrderedLink3Location)
(ordered_link4 (ordered_link4_prefix) @NeorgOrderedLink4 location: (link) @NeorgOrderedLink4Location)
(ordered_link5 (ordered_link5_prefix) @NeorgOrderedLink5 location: (link) @NeorgOrderedLink5Location)
(ordered_link6 (ordered_link6_prefix) @NeorgOrderedLink6 location: (link) @NeorgOrderedLink6Location)

; Quotes
(quote1 (quote1_prefix) @NeorgQuote1 content: (paragraph_segment) @NeorgQuote1Content)
(quote2 (quote2_prefix) @NeorgQuote2 content: (paragraph_segment) @NeorgQuote2Content)
(quote3 (quote3_prefix) @NeorgQuote3 content: (paragraph_segment) @NeorgQuote3Content)
(quote4 (quote4_prefix) @NeorgQuote4 content: (paragraph_segment) @NeorgQuote4Content)
(quote5 (quote5_prefix) @NeorgQuote5 content: (paragraph_segment) @NeorgQuote5Content)
(quote6 (quote6_prefix) @NeorgQuote6 content: (paragraph_segment) @NeorgQuote6Content)

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

(inline_comment) @comment

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
            (link_location
                type: (link_target_footnote)
            )
        ) @conceal
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
