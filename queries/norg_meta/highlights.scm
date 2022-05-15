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
(pair
    (key) @_key
    (value) @NeorgDocumentMetaTitle
    (#eq? @_key "title")
)

(pair
    (key) @_key
    (value) @NeorgDocumentMetaDescription
    (#eq? @_key "description")
)

(pair
    (key) @_key
    [
        (value) @NeorgDocumentMetaAuthors
        (array
            (value) @NeorgDocumentMetaAuthors
        )
    ]
    (#eq? @_key "authors")
)

(pair
    (key) @_key
    [
        (value) @NeorgDocumentMetaCategories
        (array
            (value) @NeorgDocumentMetaCategories
        )
    ]
    (#eq? @_key "categories")
)

(pair
    (key) @_key
    (value) @NeorgDocumentMetaCreated
    (#eq? @_key "created")
)

(pair
    (key) @_key
    (value) @NeorgDocumentMetaVersion
    (#eq? @_key "version")
)
