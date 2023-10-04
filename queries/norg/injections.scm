; Injection for code blocks
(verbatim_ranged_tag (tag_name) @_tagname .(parameter) @injection.language (verbatim_content) @injection.content (#any-of? @_tagname "code" "embed"))
(verbatim_ranged_tag (tag_name) @_tagname (verbatim_content) @injection.content (#eq? @_tagname "math") (#set! injection.language "latex"))

; (
;     (inline_math) @injection.content
;     (#offset! @injection.content 0 1 0 -1)
;     (#set! injection.language "latex")
; )

(verbatim_ranged_tag (tag_name) @_tagname (verbatim_content) @injection.content (#eq? @_tagname "document.meta") (#set! injection.language "norg_meta"))
