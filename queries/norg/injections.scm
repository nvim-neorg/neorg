; Injection for code blocks
(ranged_tag (tag_name) @_tagname (tag_parameters) @language (ranged_tag_content) @content (#eq? @_tagname "code") (#not-eq? @language "norg"))
(ranged_tag (tag_name) @_tagname (tag_parameters)? (ranged_tag_content) @latex (#eq? @_tagname "math"))

(ranged_tag (tag_name) @_tagname (ranged_tag_content) @norg_table (#eq? @_tagname "table"))
