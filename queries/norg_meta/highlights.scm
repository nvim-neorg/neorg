; Regular keys and values
(key) @NeorgDocumentMetaKey
(value) @NeorgDocumentMetaValue

; Values within arrays
(array
    (value) @NeorgDocumentMetaArrayValue
)

; Literals
"{" @NeorgDocumentMetaObjectBracket
"}" @NeorgDocumentMetaObjectBracket
"[" @NeorgDocumentMetaArrayBracket
"]" @NeorgDocumentMetaArrayBracket
"~\n" @NeorgDocumentMetaCarryover

; Special Highlights
(metadata
    (pair
        (key) @_key
        (value) @NeorgDocumentMetaTitle
        (#eq? @_key "title")
    )
)
