; Tags
; "@" @Neorgkeyword
; "$" @Neorgkeyword
; "@Neorgend" @Neorgkeyword
; (tag_name) @Neorgkeyword
; (tag_parameters) @Neorgparameter
; (tag_content) @NeorgNormal
; ("@" (tag_name) @Neorgkeyword (tag_parameters)? (tag_content) @Neorgcomment (#match? @Neorgkeyword "^comment$"))
; ("$" (tag_name) @Neorgkeyword (tag_parameters)? (paragraph) @Neorgcomment (#match? @Neorgkeyword "^comment$"))

; ; Headings
; (heading1) @Neorgkeyword
; (heading2) @Neorgmethod
; (heading3) @Neorgconstant
; (heading4) @Neorgstring

; ; Display errors
; (ERROR) @Neorgerror

; ; Markers and Drawers
; (marker (paragraph_segment) @Neorgnormal) @Neorgcomment
; (drawer) @Neorgcomment
; (drawer (paragraph_segment) @Neorgnamespace)
; (drawer_content) @Neorgnormal

; ; Escape sequences (\char)
; (escape_sequence) @Neorgtag

; ; Todo Items
; (todo_item_prefix) @NeorgSpecial
; (todo_item_suffix) @NeorgSpecial
; (todo_item_pending_mark) @Neorgtag
; (todo_item_done_mark) @Neorgstring

; ; Unordered lists
; (unordered_list_prefix) @Neorgcomment

; ; Quotes
; (quote) @Neorgstring


"@" @NeorgTagBegin
"$" @NeorgTagBegin
"@end" @NeorgTagEnd
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
