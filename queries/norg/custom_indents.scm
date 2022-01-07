(heading1
    (heading1_prefix)

    ; Make sure the indentation aligns to the title
    title: (paragraph_segment) @prefix
    (#align-indent! @prefix)

    ; Specifying indent here acts as a guide
    ; to determine where the cursor should be for the indent to trigger
    (_) @indent
)
