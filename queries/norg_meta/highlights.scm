; Regular keys and values
(key) @neorg.tags.ranged_verbatim.document_meta.key
(value) @neorg.tags.ranged_verbatim.document_meta.value

; Values within arrays
(array
    (value) @neorg.tags.ranged_verbatim.document_meta.array.value
)

; Literals
"{" @neorg.tags.ranged_verbatim.document_meta.object.bracket
"}" @neorg.tags.ranged_verbatim.document_meta.object.bracket
"[" @neorg.tags.ranged_verbatim.document_meta.array.bracket
"]" @neorg.tags.ranged_verbatim.document_meta.array.bracket
"~\n" @neorg.tags.ranged_verbatim.document_meta.trailing

; Special Highlights
(pair
    (key) @_key
    (value) @neorg.tags.ranged_verbatim.document_meta.title
    (#eq? @_key "title")
)

(pair
    (key) @_key
    (value) @neorg.tags.ranged_verbatim.document_meta.description
    (#eq? @_key "description")
)

(pair
    (key) @_key
    [
        (value) @neorg.tags.ranged_verbatim.document_meta.authors
        (array
            (value) @neorg.tags.ranged_verbatim.document_meta.authors
        )
    ]
    (#eq? @_key "authors")
)

(pair
    (key) @_key
    [
        (value) @neorg.tags.ranged_verbatim.document_meta.categories
        (array
            (value) @neorg.tags.ranged_verbatim.document_meta.categories
        )
    ]
    (#eq? @_key "categories")
)

(pair
    (key) @_key
    (value) @neorg.tags.ranged_verbatim.document_meta.created
    (#eq? @_key "created")
)

(pair
    (key) @_key
    (value) @neorg.tags.ranged_verbatim.document_meta.updated
    (#eq? @_key "updated")
)

(pair
    (key) @_key
    (value) @neorg.tags.ranged_verbatim.document_meta.version
    (#eq? @_key "version")
)
