<div align="center">

# `core.concealer`

### Display Markup as Icons, not Text

The concealer module converts verbose markup elements into beautified icons for your viewing pleasure.

![module-showcase](https://user-images.githubusercontent.com/76052559/216767027-726b451d-6da1-4d09-8fa4-d08ec4f93f54.png)

</div>

# Overview

"Concealing" is the process of hiding away from plain sight. When writing raw Norg, long strings like
`***** Hello` or `$$ Definition` can be distracting and sometimes unpleasant when sifting through large notes.

To reduce the amount of cognitive load required to "parse" Norg documents with your own eyes, this module
masks, or sometimes completely hides many categories of markup.

The concealer depends on [Nerd Fonts >=v3.0.1](https://github.com/ryanoasis/nerd-fonts/releases/latest) to be
installed on your system.

# Configuration

* <details open>
  
  <summary><h6><code>folds</h6></code> (boolean)</summary>
  
  <div>
  
  If true, Neorg will enable folding by default for `.norg` documents.
  You may use the inbuilt Neovim folding options like `foldnestmax`,
  `foldlevelstart` and others to then tune the behaviour to your liking.
  
  Set to `false` if you do not want Neorg setting anything.
  
  </div>
  
  ```lua
  true
  ```
  
  </details>

* <details open>
  
  <summary><h6><code>icon_preset</h6></code> (string)</summary>
  
  <div>
  
  Which icon preset to use.
  
  The currently available icon presets are:
  - "basic" - use a mixture of icons (includes cute flower icons!)
  - "diamond" - use diamond shapes for headings
  - "varied" - use a mix of round and diamond shapes for headings; no cute flower icons though :(
  
  </div>
  
  ```lua
  "basic"
  ```
  
  </details>

* <details open>
  
  <summary><h6><code>icons</h6></code> (table)</summary>
  
  <div>
  
  Configuration for icons.
  
  This table contains the full configuration set for each icon, including
  its query (where to be placed), render functions (how to be placed) and
  characters to use.
  
  For most use cases, the only values that you should be changing is the `icon`/`icons` field.
  `icon` is a string, while `icons` is a table of strings for multilevel elements like
  headings, lists, and quotes.
  
  To disable part of the config, replace the table with `false`, or prepend `false and` to it.
  For example: `done = false` or `done = false and { ... }`.
  
  </div>
  
  
  * <details>
    
    <summary><h6><code>code_block</h6></code> (table)</summary>
    
    <div>
    
    Options that control the behaviour of code block dimming
    (placing a darker background behind `@code` tags).
    
    </div>
    
    
    * <details>
      
      <summary><h6><code>conceal</h6></code> (boolean)</summary>
      
      <div>
      
      If `true` will conceal (hide) the `@code` and `@end` portion of the code
      block.
      
      </div>
      
      ```lua
      false
      ```
      
      </details>
    * <details>
      
      <summary><h6><code>content_only</h6></code> (boolean)</summary>
      
      <div>
      
      If true will only dim the content of the code block (without the
      `@code` and `@end` lines), not the entirety of the code block itself.
      
      </div>
      
      ```lua
      true
      ```
      
      </details>
    * <details>
      
      <summary><h6><code>highlight</h6></code> (string)</summary>
      
      <br>
      
      ```lua
      "@neorg.tags.ranged_verbatim.code_block"
      ```
      
      </details>
    * <details>
      
      <summary><h6><code>insert_enabled</h6></code> (boolean)</summary>
      
      <br>
      
      ```lua
      true
      ```
      
      </details>
    * <details>
      
      <summary><h6><code>nodes</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "ranged_verbatim_tag"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>padding</h6></code> (table)</summary>
      
      <div>
      
      Additional padding to apply to either the left or the right. Making
      these values negative is considered undefined behaviour (it is
      likely to work, but it's not officially supported).
      
      </div>
      
      
      * <details>
        
        <summary><h6><code>left</h6></code> (number)</summary>
        
        <br>
        
        ```lua
        0
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>right</h6></code> (number)</summary>
        
        <br>
        
        ```lua
        0
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>render</h6></code> (function)</summary>
      
      <br>
      
      ```lua
      module.public.icon_renderers.render_code_block
      ```
      
      </details>
    * <details>
      
      <summary><h6><code>spell_check</h6></code> (boolean)</summary>
      
      <div>
      
      If `false` will disable spell check on code blocks when 'spell' option is switched on.
      
      </div>
      
      ```lua
      true
      ```
      
      </details>
    * <details>
      
      <summary><h6><code>width</h6></code> (string)</summary>
      
      <div>
      
      The width to use for code block backgrounds.
      
      When set to `fullwidth` (the default), will create a background
      that spans the width of the buffer.
      
      When set to `content`, will only span as far as the longest line
      within the code block.
      
      </div>
      
      ```lua
      "fullwidth"
      ```
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>definition</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>multi_prefix</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "⋙ "
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "multi_definition_prefix"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>multi_suffix</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "⋘ "
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "multi_definition_suffix"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>single</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "≡"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (table)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "single_definition_prefix"
          ```
          
          </details>
        * <details>
          
          <summary><h6><code>concealed</h6></code> (list)</summary>
          
          <br>
          
          
          * <details>
            
            <summary> (string)</summary>
            
            <br>
            
            ```lua
            "link_target_definition"
            ```
            
            </details>
          
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>delimiter</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>horizontal_line</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>highlight</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.delimiters.horizontal_line"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "─"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>left</h6></code> (string)</summary>
        
        <div>
        
        The starting position of horizontal lines:
        - "window": the horizontal line starts from the first column, reaching the left of the window
        - "here": the horizontal line starts from the node column
        
        </div>
        
        ```lua
        "here"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "horizontal_line"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.render_horizontal_line
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>right</h6></code> (string)</summary>
        
        <div>
        
        The ending position of horizontal lines:
        - "window": the horizontal line ends at the last column, reaching the right of the window
        - "textwidth": the horizontal line ends at column `textwidth` or 79 when it's set to zero
        
        </div>
        
        ```lua
        "window"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>strong</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>highlight</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.delimiters.strong"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "⟪"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "strong_paragraph_delimiter"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.fill_text
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>weak</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>highlight</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.delimiters.weak"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "⟨"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "weak_paragraph_delimiter"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.fill_text
        ```
        
        </details>
      
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>footnote</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>multi_prefix</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "⁑ "
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "multi_footnote_prefix"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>multi_suffix</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "⁑ "
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "multi_footnote_suffix"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>single</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "⁎"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (table)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "single_footnote_prefix"
          ```
          
          </details>
        * <details>
          
          <summary><h6><code>concealed</h6></code> (list)</summary>
          
          <br>
          
          
          * <details>
            
            <summary> (string)</summary>
            
            <br>
            
            ```lua
            "link_target_footnote"
            ```
            
            </details>
          
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>numeric_superscript</h6></code> (boolean)</summary>
        
        <div>
        
        When set to true, footnote link with numeric title will be
        concealed to superscripts.
        
        </div>
        
        ```lua
        true
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>render_concealed</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.footnote_concealed
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>title_highlight</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.footnotes.title"
        ```
        
        </details>
      
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>heading</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>highlights</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.headings.1.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.headings.2.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.headings.3.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.headings.4.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.headings.5.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.headings.6.prefix"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>icons</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "◉"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "◎"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "○"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "✺"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "▶"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "⤷"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>nodes</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "heading1_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "heading2_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "heading3_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "heading4_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "heading5_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "heading6_prefix"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>concealed</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "link_target_heading1"
          ```
          
          </details>
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "link_target_heading2"
          ```
          
          </details>
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "link_target_heading3"
          ```
          
          </details>
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "link_target_heading4"
          ```
          
          </details>
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "link_target_heading5"
          ```
          
          </details>
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "link_target_heading6"
          ```
          
          </details>
        
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>render</h6></code> (function)</summary>
      
      <br>
      
      ```lua
      module.public.icon_renderers.multilevel_on_right
      ```
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>list</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>icons</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "•"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>nodes</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "unordered_list1_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "unordered_list2_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "unordered_list3_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "unordered_list4_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "unordered_list5_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "unordered_list6_prefix"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>render</h6></code> (function)</summary>
      
      <br>
      
      ```lua
      module.public.icon_renderers.multilevel_on_right
      ```
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>markup</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>spoiler</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>highlight</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.markup.spoiler"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "•"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "spoiler"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.fill_multiline_chop2
        ```
        
        </details>
      
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>ordered</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>formatters</h6></code> (list)</summary>
      
      <div>
      
      A list of lua patterns specifying how to format each
      nesting level of an ordered list.
      
      `%s` is substituted with the string returned by the `generator`.
      
      </div>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "%s."
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "%s."
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "%s."
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "(%s)"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>generators</h6></code> (list)</summary>
      
      <div>
      
      A list of icon generators.
      
      Icon generators live in the `icon_generators` namespace. They create
      a unique ID for each index in the list. This can be as simple as `1, 2, 3, 4...`
      or `A, B, C, D...`, but one could opt for more complex generators.
      
      </div>
      
      
      * <details>
        
        <summary> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_generators.numeric
        ```
        
        </details>
      * <details>
        
        <summary> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_generators.alphanumeric_uppercase
        ```
        
        </details>
      * <details>
        
        <summary> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_generators.alphanumeric_lowercase
        ```
        
        </details>
      * <details>
        
        <summary> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_generators.numeric
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>icons</h6></code> (list)</summary>
      
      <br>
      
      ```lua
      (not has_anticonceal) and { "⒈", "A", "a", "⑴", "Ⓐ", "ⓐ" } or nil
      ```
      
      </details>
    * <details>
      
      <summary><h6><code>nodes</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "ordered_list1_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "ordered_list2_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "ordered_list3_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "ordered_list4_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "ordered_list5_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "ordered_list6_prefix"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>render</h6></code> (function)</summary>
      
      <br>
      
      ```lua
      has_anticonceal and module.public.icon_renderers.multilevel_ordered_inline_on_right                 or module.public.icon_renderers.multilevel_ordered_on_right
      ```
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>quote</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>highlights</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.quotes.1.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.quotes.2.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.quotes.3.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.quotes.4.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.quotes.5.prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "@neorg.quotes.6.prefix"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>icons</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "│"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>nodes</h6></code> (list)</summary>
      
      <br>
      
      
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "quote1_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "quote2_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "quote3_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "quote4_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "quote5_prefix"
        ```
        
        </details>
      * <details>
        
        <summary> (string)</summary>
        
        <br>
        
        ```lua
        "quote6_prefix"
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>render</h6></code> (function)</summary>
      
      <br>
      
      ```lua
      module.public.icon_renderers.multilevel_copied
      ```
      
      </details>
    
    
    </details>
  * <details>
    
    <summary><h6><code>todo</h6></code> (table)</summary>
    
    <br>
    
    
    * <details>
      
      <summary><h6><code>cancelled</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        ""
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "todo_item_cancelled"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>done</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "󰄬"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "todo_item_done"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>on_hold</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        ""
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "todo_item_on_hold"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>pending</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "󰥔"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "todo_item_pending"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>recurring</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "↺"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "todo_item_recurring"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>uncertain</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        ""
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "todo_item_uncertain"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>undone</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "×"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "todo_item_undone"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    * <details>
      
      <summary><h6><code>urgent</h6></code> (table)</summary>
      
      <br>
      
      
      * <details>
        
        <summary><h6><code>icon</h6></code> (string)</summary>
        
        <br>
        
        ```lua
        "⚠"
        ```
        
        </details>
      * <details>
        
        <summary><h6><code>nodes</h6></code> (list)</summary>
        
        <br>
        
        
        * <details>
          
          <summary> (string)</summary>
          
          <br>
          
          ```lua
          "todo_item_urgent"
          ```
          
          </details>
        
        
        </details>
      * <details>
        
        <summary><h6><code>render</h6></code> (function)</summary>
        
        <br>
        
        ```lua
        module.public.icon_renderers.on_left
        ```
        
        </details>
      
      
      </details>
    
    
    </details>
  
  
  </details>

* <details open>
  
  <summary><h6><code>init_open_folds</h6></code> (string)</summary>
  
  <div>
  
  When set to `auto`, Neorg will open all folds when opening new documents if `foldlevel` is 0.
  When set to `always`, Neorg will always open all folds when opening new documents.
  When set to `never`, Neorg will not do anything.
  
  </div>
  
  ```lua
  "auto"
  ```
  
  </details>


# Required Modules

- [`core.autocommands`](https://github.com/nvim-neorg/neorg/wiki/Autocommands) - Handles the creation and management of Neovim's autocommands.
- [`core.integrations.treesitter`](https://github.com/nvim-neorg/neorg/wiki/Treesitter-Integration) - A module designed to integrate Treesitter into Neorg.

