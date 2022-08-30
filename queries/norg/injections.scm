; Injection for code blocks
(ranged_tag (tag_name) @_tagname (tag_parameters parameter: (tag_param) @language) (ranged_tag_content) @content (#any-of? @_tagname "code" "embed") (#not-eq? @language "norg"))
(ranged_tag (tag_name) @_tagname (tag_parameters)? (ranged_tag_content) @latex (#eq? @_tagname "math"))

(
    (inline_math) @latex
    (#offset! @latex 0 1 0 -1)
)

(ranged_tag (tag_name) @_tagname (ranged_tag_content) @norg_meta (#eq? @_tagname "document.meta"))

(ranged_tag (tag_name) @_tagname (ranged_tag_content) @norg_table (#eq? @_tagname "table"))
