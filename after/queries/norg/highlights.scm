; "@" @NeorgTagBegin
; "$" @NeorgTagBegin
; (tag_end) @NeorgTagEnd
; (tag_name) @NeorgTagName
; (tag_parameters) @NeorgTagParameters
; (tag_content) @NeorgTagContent
; ("@" (tag_name) @NeorgTagName (tag_parameters)? (tag_content) @NeorgTagComment (#match? @NeorgTagName "^comment$"))
; ("$" (tag_name) @NeorgTagName (tag_parameters)? (_)+ @NeorgTagComment (#match? @NeorgTagName "^comment$"))

; Headings
(heading1 title: (paragraph_segment) @NeorgHeading1) 
(heading2 title: (paragraph_segment) @NeorgHeading2) 
(heading3 title: (paragraph_segment) @NeorgHeading3) 
(heading4 title: (paragraph_segment) @NeorgHeading4) 
(heading5 title: (paragraph_segment) @NeorgHeading5) 
(heading6 title: (paragraph_segment) @NeorgHeading6) 

; Display errors
(ERROR) @TSError

; Markers and Drawers
(marker (marker_prefix) @NeorgMarker (paragraph_segment) @NeorgMarkerTitle)
; (drawer) @NeorgDrawer
; (drawer (paragraph_segment) @NeorgDrawerTitle)
; (drawer_content) @NeorgDrawerContent

; Escape sequences (\char)
(escape_sequence) @NeorgEscapeSequence

; Todo Items
(todo_item ("_prefix") @NeorgTodoItem)
(todo_item ("_suffix") @NeorgTodoItem)
(todo_item_pending) @NeorgTodoItemPendingMark
(todo_item_done) @NeorgTodoItemDoneMark

; Unordered lists
(unordered_list_prefix) @NeorgUnorderedList
(unordered_link ("_prefix") @NeorgUnorderedLinkList)

; Quotes
(quote) @NeorgQuote
(quote (paragraph_segment) @NeorgQuoteContent)
