--[[
    file: Nvim-Cmp
    title: Integrating Neorg with `nvim-cmp`
    summary: A module for integrating nvim-cmp with Neorg.
    internal: true
    ---
This module works with the [`core.completion`](@core.completion) module to attempt to provide
intelligent completions. Note that integrations like this are second-class citizens and may not work in 100%
of scenarios. If they don't then please file a bug report!

After setting up `core.completion` with the `engine` set to `nvim-cmp`, make sure to also set up "neorg"
as a source in `nvim-cmp`:
```lua
sources = {
    { name = "neorg" },
},
```
--]]

local neorg = require("neorg.core")
local log, modules = neorg.log, neorg.modules

local module = modules.create("core.integrations.nvim-cmp")

module.private = {
    source = {},
    cmp = {},
    completions = {},
}

module.load = function()
    local success, cmp = pcall(require, "cmp")

    if not success then
        log.fatal("nvim-cmp not found, aborting...")
        return
    end

    module.private.cmp = cmp
end

---@class core.integrations.nvim-cmp
module.public = {
    create_source = function()
        module.private.completion_item_mapping = {
            Directive = module.private.cmp.lsp.CompletionItemKind.Keyword,
            Tag = module.private.cmp.lsp.CompletionItemKind.Keyword,
            Language = module.private.cmp.lsp.CompletionItemKind.Property,
            TODO = module.private.cmp.lsp.CompletionItemKind.Event,
            Property = module.private.cmp.lsp.CompletionItemKind.Property,
            Format = module.private.cmp.lsp.CompletionItemKind.Property,
            Embed = module.private.cmp.lsp.CompletionItemKind.Property,
            Reference = module.private.cmp.lsp.CompletionItemKind.Reference,
            File = module.private.cmp.lsp.CompletionItemKind.File,
        }

        module.private.source.new = function()
            return setmetatable({}, { __index = module.private.source })
        end

        function module.private.source.complete(_, request, callback)
            local abstracted_context = module.public.create_abstracted_context(request)

            local completion_cache = module.public.invoke_completion_engine(abstracted_context)

            if completion_cache.options.pre then
                completion_cache.options.pre(abstracted_context)
            end

            local completions = vim.deepcopy(completion_cache.items)

            for index, element in ipairs(completions) do
                local word = element
                local label = element
                if type(element) == "table" then
                    word = element[1]
                    label = element.label
                end
                completions[index] = {
                    word = word,
                    label = label,
                    kind = module.private.completion_item_mapping[completion_cache.options.type],
                }
            end

            callback(completions)
        end

        function module.private.source:get_trigger_characters()
            return { "@", "-", "(", " ", ".", ":", "#", "*", "^" }
        end

        function module.private.source:is_available()
            return vim.bo.filetype == "norg"
        end

        module.private.cmp.register_source("neorg", module.private.source)
    end,

    create_abstracted_context = function(request)
        return {
            start_offset = request.offset,
            char = request.context.cursor.character,
            before_char = request.completion_context.triggerCharacter,
            line = request.context.cursor_before_line,
            column = request.context.cursor.col,
            buffer = request.context.bufnr,
            line_number = request.context.cursor.line,
            previous_context = {
                line = request.context.prev_context.cursor_before_line,
                column = request.context.prev_context.cursor.col,
                start_offset = request.offset,
            },
            full_line = request.context.cursor_line,
        }
    end,

    invoke_completion_engine = function(context)
        error("`invoke_completion_engine` must be set from outside.")
        assert(context)
        return {}
    end,
}

return module
