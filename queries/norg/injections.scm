; Injection for code blocks
(ranged_verbatim_tag (tag_name) @_tagname (tag_parameters (tag_param) @language) (ranged_verbatim_tag_content) @content (#eq? @_tagname "code") (#not-eq? @language "norg"))
(ranged_verbatim_tag (tag_name) @_tagname (tag_parameters)? (ranged_verbatim_tag_content) @latex (#eq? @_tagname "math"))

; doesn't work rn: (ranged_tag (tag_name) @_tagname (tag_parameters)? (ranged_tag_content) @norg (#eq? @_tagname "example"))

(
    (inline_math) @latex
    (#offset! @latex 0 1 0 -1)
)

(ranged_verbatim_tag (tag_name) @_tagname (ranged_verbatim_tag_content) @norg_meta (#eq? @_tagname "document.meta"))

(ranged_verbatim_tag (tag_name) @_tagname (ranged_verbatim_tag_content) @norg_table (#eq? @_tagname "table"))
