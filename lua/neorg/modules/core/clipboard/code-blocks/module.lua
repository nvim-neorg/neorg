--[[
    file: Clipboard-Code-Blocks
    title: Comfortable Code Copying in Neorg
    summary: Removes beginning whitespace from text copied from code blocks.
    embed: https://user-images.githubusercontent.com/76052559/216775085-7e808dbd-4985-49fa-b4c2-069b9782b300.gif
    ---
The `code-blocks` module removes leading whitespace when copying from an `@code` tag, allowing
for easy pasting into external applications.

To use it, simply highlight some code within an `@code` block and paste it elsewhere!
This functionality will **only** work if the selection is inside the `@code` section,
excluding the `@code` and `@end` portion itself.

If the conditions are not met, the content is copied normally, preserving all indentation.
--]]

local module = neorg.modules.create("core.clipboard.code-blocks")

module.load = function()
    neorg.modules.await("core.clipboard", function(clipboard)
        clipboard.add_callback("ranged_verbatim_tag_content", function(node, content, position)
            -- TODO: Handle visual/visual line/visual block modes

            -- The end of "ranged_tag_content" spans one line too many
            if position["end"][1] > node:end_() - 1 then
                return
            end

            local _, indentation = node:start()

            for i, line in ipairs(content) do
                content[i] = line:sub(indentation + 1)
            end

            return content
        end, true)
    end)
end

return module
