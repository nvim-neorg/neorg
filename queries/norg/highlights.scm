(ranged_tag ("_prefix") @NeorgTagBegin
	name: (tag_name [(tag_name_element) @NeorgTagNameWord ("_delimiter") @NeorgTagNameDelimiter]+) @NeorgTagName
	(tag_parameters parameter: (word) @NeorgTagParameter)? @NeorgTagParameters
	content: (ranged_tag_content)? @NeorgTagContent
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
                ]+
            ) @NeorgCarryoverTagName
        (tag_parameters
            parameter: (word) @NeorgCarryoverTagParameter
        )? @NeorgCarryoverTagParameters
    ) @NeorgCarryoverTag

	target: (_)+ @NeorgCarryoverTagTarget
)

; Links
(link
    (link_text
        ("_prefix") @NeorgLinkTextDelimiter
        link_text: (text) @NeorgLinkText
        ("_suffix") @NeorgLinkTextDelimiter
    )
    (link_location
        ("_prefix") @NeorgLinkLocationDelimiter

        (link_file
            ("_prefix") @NeorgLinkLocationFileDelimiter
            location: (link_file_location) @NeorgLinkLocationFile
            ("_suffix") @NeorgLinkLocationFileDelimiter
        )?
        (link_end
            [
                (
                    (link_end_url) ; Doesn't require a highlight since it's a 0-width node
                    (text) @NeorgLinkLocationURL
                )
                (
                    (link_end_generic) @NeorgLinkLocationGenericPrefix
                    (text) @NeorgLinkLocationGeneric
                )
                (
                    (link_end_external_file) @NeorgLinkLocationExternalFilePrefix
                    (text) @NeorgLinkLocationExternalFile
                )
                (
                    (link_end_marker_reference) @NeorgLinkLocationMarkerPrefix
                    (text) @NeorgLinkLocationMarker
                )
                (
                    (link_end_heading1_reference) @NeorgLinkLocationHeading1Prefix
                    (text) @NeorgLinkLocationHeading1
                )
                (
                    (link_end_heading2_reference) @NeorgLinkLocationHeading2Prefix
                    (text) @NeorgLinkLocationHeading2
                )
                (
                    (link_end_heading3_reference) @NeorgLinkLocationHeading3Prefix
                    (text) @NeorgLinkLocationHeading3
                )
                (
                    (link_end_heading4_reference) @NeorgLinkLocationHeading4Prefix
                    (text) @NeorgLinkLocationHeading4
                )
                (
                    (link_end_heading5_reference) @NeorgLinkLocationHeading5Prefix
                    (text) @NeorgLinkLocationHeading5
                )
                (
                    (link_end_heading6_reference) @NeorgLinkLocationHeading6Prefix
                    (text) @NeorgLinkLocationHeading6
                )
            ]
        )?

        ("_suffix") @NeorgLinkLocationDelimiter
    )
) @NeorgLink

; Is there a better way to do this?
(strict_link
    (link_text
        ("_prefix") @NeorgLinkTextDelimiter
        link_text: (text) @NeorgLinkText
        ("_suffix") @NeorgLinkTextDelimiter
    )
    (link_location
        ("_prefix") @NeorgLinkLocationDelimiter

        (link_file
            ("_prefix") @NeorgLinkLocationFileDelimiter
            location: (link_file_location) @NeorgLinkLocationFile
            ("_suffix") @NeorgLinkLocationFileDelimiter
        )?
        (link_end
            [
                (
                    (link_end_url) ; Doesn't require a highlight since it's a 0-width node
                    (text) @NeorgLinkLocationURL
                )
                (
                    (link_end_generic) @NeorgLinkLocationGenericPrefix
                    (text) @NeorgLinkLocationGeneric
                )
                (
                    (link_end_external_file) @NeorgLinkLocationExternalFilePrefix
                    (text) @NeorgLinkLocationExternalFile
                )
                (
                    (link_end_marker_reference) @NeorgLinkLocationMarkerPrefix
                    (text) @NeorgLinkLocationMarker
                )
                (
                    (link_end_heading1_reference) @NeorgLinkLocationHeading1Prefix
                    (text) @NeorgLinkLocationHeading1
                )
                (
                    (link_end_heading2_reference) @NeorgLinkLocationHeading2Prefix
                    (text) @NeorgLinkLocationHeading2
                )
                (
                    (link_end_heading3_reference) @NeorgLinkLocationHeading3Prefix
                    (text) @NeorgLinkLocationHeading3
                )
                (
                    (link_end_heading4_reference) @NeorgLinkLocationHeading4Prefix
                    (text) @NeorgLinkLocationHeading4
                )
                (
                    (link_end_heading5_reference) @NeorgLinkLocationHeading5Prefix
                    (text) @NeorgLinkLocationHeading5
                )
                (
                    (link_end_heading6_reference) @NeorgLinkLocationHeading6Prefix
                    (text) @NeorgLinkLocationHeading6
                )
            ]
        )?

        ("_suffix") @NeorgLinkLocationDelimiter
    )
) @NeorgLink

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
(single_definition (single_definition_prefix) @NeorgDefinition title: (paragraph_segment) @NeorgDefinitionTitle definition: (_)* @NeorgDefinitionContent)
(multi_definition (multi_definition_prefix) @NeorgDefinition title: (paragraph_segment) @NeorgDefinitionTitle content: (_)* @NeorgDefinitionContent end: (multi_definition_suffix) @NeorgDefinitionEnd)

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
			(todo_item_wont_complete) @NeorgTodoItem1WontComplete
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
			(todo_item_wont_complete) @NeorgTodoItem2WontComplete
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
			(todo_item_wont_complete) @NeorgTodoItem3WontComplete
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
			(todo_item_wont_complete) @NeorgTodoItem4WontComplete
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
			(todo_item_wont_complete) @NeorgTodoItem5WontComplete
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
			(todo_item_wont_complete) @NeorgTodoItem6WontComplete
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

; Unordered links
(unordered_link1 (unordered_link1_prefix) @NeorgUnorderedLink1 location: (strict_link) @NeorgUnorderedLink1Location)
(unordered_link2 (unordered_link2_prefix) @NeorgUnorderedLink2 location: (strict_link) @NeorgUnorderedLink2Location)
(unordered_link3 (unordered_link3_prefix) @NeorgUnorderedLink3 location: (strict_link) @NeorgUnorderedLink3Location)
(unordered_link4 (unordered_link4_prefix) @NeorgUnorderedLink4 location: (strict_link) @NeorgUnorderedLink4Location)
(unordered_link5 (unordered_link5_prefix) @NeorgUnorderedLink5 location: (strict_link) @NeorgUnorderedLink5Location)
(unordered_link6 (unordered_link6_prefix) @NeorgUnorderedLink6 location: (strict_link) @NeorgUnorderedLink6Location)

; Ordered links
(ordered_link1 (ordered_link1_prefix) @NeorgOrderedLink1 location: (strict_link) @NeorgOrderedLink1Location)
(ordered_link2 (ordered_link2_prefix) @NeorgOrderedLink2 location: (strict_link) @NeorgOrderedLink2Location)
(ordered_link3 (ordered_link3_prefix) @NeorgOrderedLink3 location: (strict_link) @NeorgOrderedLink3Location)
(ordered_link4 (ordered_link4_prefix) @NeorgOrderedLink4 location: (strict_link) @NeorgOrderedLink4Location)
(ordered_link5 (ordered_link5_prefix) @NeorgOrderedLink5 location: (strict_link) @NeorgOrderedLink5Location)
(ordered_link6 (ordered_link6_prefix) @NeorgOrderedLink6 location: (strict_link) @NeorgOrderedLink6Location)

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
(bold) @NeorgMarkupBold
(italic) @NeorgMarkupItalic
(strikethrough) @NeorgMarkupStrikethrough
(underline) @NeorgMarkupUnderline
(spoiler) @NeorgMarkupSpoiler
(verbatim) @NeorgMarkupVerbatim
(superscript) @NeorgMarkupSuperscript
(subscript) @NeorgMarkupSubscript
(inline_comment) @NeorgMarkupInlineComment
(inline_math) @NeorgMarkupInlineMath
(variable) @NeorgMarkupVariable
