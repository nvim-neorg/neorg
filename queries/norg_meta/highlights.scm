; Regular keys and values
(key) @neorg.tags.ranged_verbatim.document_meta.key
(string) @neorg.tags.ranged_verbatim.document_meta.string
(number) @neorg.tags.ranged_verbatim.document_meta.number

; Literals
"{" @neorg.tags.ranged_verbatim.document_meta.object.bracket
"}" @neorg.tags.ranged_verbatim.document_meta.object.bracket
"[" @neorg.tags.ranged_verbatim.document_meta.array.bracket
"]" @neorg.tags.ranged_verbatim.document_meta.array.bracket

; Special Highlights
(pair
    (key) @_key
    (string) @neorg.tags.ranged_verbatim.document_meta.title
    (#eq? @_key "title")
)

(pair
    (key) @_key
    (string) @neorg.tags.ranged_verbatim.document_meta.description
    (#eq? @_key "description")
)

(pair
    (key) @_key
    [
        (string) @neorg.tags.ranged_verbatim.document_meta.authors
        (array
            (string) @neorg.tags.ranged_verbatim.document_meta.authors
        )
    ]
    (#eq? @_key "authors")
)

(pair
    (key) @_key
    [
        (string) @neorg.tags.ranged_verbatim.document_meta.categories
        (array
            (string) @neorg.tags.ranged_verbatim.document_meta.categories
        )
    ]
    (#eq? @_key "categories")
)

(pair
    (key) @_key
    (string) @neorg.tags.ranged_verbatim.document_meta.created
    (#eq? @_key "created")
)

(pair
    (key) @_key
    (string) @neorg.tags.ranged_verbatim.document_meta.updated
    (#eq? @_key "updated")
)

(pair
    (key) @_key
    (string) @neorg.tags.ranged_verbatim.document_meta.version
    (#eq? @_key "version")
)
