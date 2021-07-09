"@" @NeorgTagBegin
"$" @NeorgTagBegin
(tag_end) @NeorgTagEnd
(tag_name) @NeorgTagName
(tag_parameters) @NeorgTagParameters
(tag_content) @NeorgTagContent
("@" (tag_name) @NeorgTagName (tag_parameters)? (tag_content) @NeorgTagComment (#match? @NeorgTagName "^comment$"))
("$" (tag_name) @NeorgTagName (tag_parameters)? (paragraph) @NeorgTagComment (#match? @NeorgTagName "^comment$"))

; Headings
(heading1) @NeorgHeading1
(heading2) @NeorgHeading2
(heading3) @NeorgHeading3
(heading4) @NeorgHeading4

; Display errors
(ERROR) @NeorgError

; Markers and Drawers
(marker (paragraph_segment) @NeorgMarkerTitle) @NeorgMarker
(drawer) @NeorgDrawer
(drawer (paragraph_segment) @NeorgDrawerTitle)
(drawer_content) @NeorgDrawerContent

; Escape sequences (\char)
(escape_sequence) @NeorgEscapeSequence

; Todo Items
(todo_item_prefix) @NeorgTodoItem
(todo_item_suffix) @NeorgTodoItem
(todo_item_pending_mark) @NeorgTodoItemPendingMark
(todo_item_done_mark) @NeorgTodoItemDoneMark

; Unordered lists
(unordered_list_prefix) @NeorgUnorderedList

; Quotes
(quote) @NeorgQuote
(quote (paragraph_segment) @NeorgQuoteContent)
