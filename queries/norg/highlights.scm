(ranged_tag
    ("_prefix") @NeorgTagBegin
	name: (tag_name
        [(word) @NeorgTagNameWord ("_delimiter") @NeorgTagNameDelimiter]+) @NeorgTagName
	(tag_parameters (tag_param)+ @NeorgTagParameter)? @NeorgTagParameters
	content: (ranged_tag_content)?
	(ranged_tag_end ("_prefix") @NeorgTagEnd ("_name") @NeorgTagNameWord)?) @NeorgTag

(ranged_verbatim_tag
    ("_prefix") @NeorgVerbatimTagBegin
	name: (tag_name
        [(word) @NeorgVerbatimTagNameWord ("_delimiter") @NeorgVerbatimTagNameDelimiter]+) @NeorgVerbatimTagName
	(tag_parameters (tag_param)+ @NeorgVerbatimTagParameter)? @NeorgVerbatimTagParameters
	content: (ranged_verbatim_tag_content)?
	(ranged_verbatim_tag_end ("_prefix") @NeorgVerbatimTagEnd ("_name") @NeorgVerbatimTagNameWord)?) @NeorgVerbatimTag

(weak_attribute_set
    (weak_attribute
        ("_prefix" @NeorgWeakAttributeBegin)
        name:
            (tag_name
                [
                    (word) @NeorgWeakAttributeNameWord
                    ("_delimiter") @NeorgWeakAttributeNameDelimiter
                ]
            ) @NeorgWeakAttributeName
        (tag_parameters
            (tag_param) @NeorgWeakAttributeParameter
        )? @NeorgWeakAttributeParameters
    ) @NeorgWeakAttribute
)

(strong_attribute_set
    (strong_attribute
        ("_prefix" @NeorgStrongAttributeBegin)
        name:
            (tag_name
                [
                    (word) @NeorgStrongAttributeNameWord
                    ("_delimiter") @NeorgStrongAttributeNameDelimiter
                ]
            ) @NeorgStrongAttributeName
        (tag_parameters
            (tag_param) @NeorgStrongAttributeParameter
        )? @NeorgStrongAttributeParameters
    ) @NeorgStrongAttribute
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
                (link_target_heading) @NeorgLinkLocationHeadingPrefix
                (paragraph) @NeorgLinkLocationHeading
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
            (
                ("_begin") @NeorgLinkFileDelimiter
                file: (link_file_text) @NeorgLinkFile
                ("_end") @NeorgLinkFileDelimiter
            )
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
                (link_target_heading) @NeorgLinkLocationHeadingPrefix
                (paragraph) @NeorgLinkLocationHeading
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
(single_definition (single_definition_prefix) @NeorgDefinition title: (paragraph_segment) @NeorgDefinitionTitle content: _ @NeorgDefinitionContent)
(multi_definition (multi_definition_prefix) @NeorgDefinition title: (paragraph_segment) @NeorgDefinitionTitle content: _* @NeorgDefinitionContent end: (multi_definition_suffix) @NeorgDefinitionEnd)

; Footnotes
(single_footnote (single_footnote_prefix) @NeorgFootnote title: (paragraph_segment) @NeorgFootnoteTitle content: _ @NeorgFootnoteContent)
(multi_footnote (multi_footnote_prefix) @NeorgFootnote title: (paragraph_segment) @NeorgFootnoteTitle content: _* @NeorgFootnoteContent end: (multi_footnote_suffix) @NeorgFootnoteEnd)

; Escape sequences (\char)
(escape_sequence) @NeorgEscapeSequence

; Todo Items
state: [
    (todo_item_undone) @NeorgTodoItem1Undone
    (todo_item_pending) @NeorgTodoItem1Pending
    (todo_item_done) @NeorgTodoItem1Done
    (todo_item_on_hold) @NeorgTodoItem1OnHold
    (todo_item_cancelled) @NeorgTodoItem1Cancelled
    (todo_item_urgent) @NeorgTodoItem1Urgent
    (todo_item_uncertain) @NeorgTodoItem1Uncertain
    (todo_item_recurring) @NeorgTodoItem1Recurring
]

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
            (_
                [
                    "_begin"
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
