--[[
    file: Coq_nvim
    title: Integrating Neorg with `coq_nvim`
    summary: A module for integrating coq_nvim with Neorg.
    internal: true
    ---
This module works with the [`core.completion`](@core.completion) module to attempt to provide
intelligent completions. Note that integrations like this are second-class citizens and may not work in 100%
of scenarios. If they don't then please file a bug report!
--]]

local neorg = require("neorg.core")
local log, modules = neorg.log, neorg.modules

local module = modules.create("core.integrations.coq_nvim")

module.private = {
    ---@param map table<number, table>
    new_uid = function(map)
        vim.validate({
            map = { map, "table" },
        })

        local key ---@type integer|nil
        while true do
            if not key or map[key] then
                key = math.floor(math.random() * 10000)
            else
                return key
            end
        end
    end,
}

module.load = function()
    local success = pcall(require, "coq")

    if not success then
        log.fatal("coq_nvim not found, aborting...")
        return
    end
end

---@class core.integrations.coq_nvim
module.public = {
    create_source = function()
        module.private.completion_item_mapping = {
            Directive = vim.lsp.protocol.CompletionItemKind.Keyword,
            Tag = vim.lsp.protocol.CompletionItemKind.Keyword,
            Language = vim.lsp.protocol.CompletionItemKind.Property,
            TODO = vim.lsp.protocol.CompletionItemKind.Event,
            Property = vim.lsp.protocol.CompletionItemKind.Property,
            Format = vim.lsp.protocol.CompletionItemKind.Property,
            Embed = vim.lsp.protocol.CompletionItemKind.Property,
            Reference = vim.lsp.protocol.CompletionItemKind.Reference,
            File = vim.lsp.protocol.CompletionItemKind.File,
        }

        -- luacheck: push ignore 111
        -- luacheck: push ignore 112
        -- luacheck: push ignore 113
        COQsources = COQsources or {} ---@diagnostic disable undefined-global
        COQsources[module.private.new_uid(COQsources)] = {
            name = "Neorg",
            fn = function(args, callback)
                if vim.bo.filetype ~= "norg" then
                    return callback()
                end

                local completion_cache = module.public.invoke_completion_engine(args)

                if completion_cache.options.pre then
                    completion_cache.options.pre(args)
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

                callback({
                    isIncomplete = false,
                    items = completions,
                })
            end,
        }
        -- luacheck: pop
        -- luacheck: pop
        -- luacheck: pop
    end,
}

return module
