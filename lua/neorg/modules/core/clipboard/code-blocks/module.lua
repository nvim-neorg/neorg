local module = neorg.modules.create("core.clipboard.code-blocks")

module.load = function()
    neorg.modules.await("core.clipboard", function(clipboard)
        clipboard.add_callback("ranged_tag_content", function(node, content, position)
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
