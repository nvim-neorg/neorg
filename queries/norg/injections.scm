; Injection for code blocks
(ranged_verbatim_tag (tag_name) @_tagname (tag_parameters .(tag_param) @language) (ranged_verbatim_tag_content) @content (#any-of? @_tagname "code" "embed") (#not-eq? @language "norg"))
(ranged_verbatim_tag (tag_name) @_tagname (tag_parameters)? (ranged_verbatim_tag_content) @latex (#eq? @_tagname "math"))

(
    (inline_math) @latex
    (#offset! @latex 0 1 0 -1)
)

(ranged_verbatim_tag (tag_name) @_tagname (ranged_verbatim_tag_content) @norg_meta (#eq? @_tagname "document.meta"))
