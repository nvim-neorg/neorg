--[[
-- Indentation module for Neorg
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.esupports.indent")

module.setup = function()
    vim.treesitter.add_directive("align-indent!", function(match, pattern, bufnr, predicate)
        log.error(match, pattern, bufnr, predicate)
    end)

    module.private.query = vim.treesitter.get_query("norg", "custom_indents")

    return {
        success = true,
        requires = {
            "core.autocommands",
        },
    }
end

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
end

module.public = {
    generic = {
        indent = function(_) end,
    },

    lookback = {},
    realtime = {},
}

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" and event.content.norg then
        if module.private.buffer_list[event.buffer] then
            return
        end

        module.private.buffer_list[event.buffer] = true
        vim.api.nvim_buf_set_option(
            event.buffer,
            "indentexpr",
            string.format("v:lua.neorg.modules.get_module('%s').generic.indent(%s)", module.name, event.buffer)
        )
    end
end

module.private = {
    query = nil,
    buffer_list = {},
}

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
    },
}

return module
