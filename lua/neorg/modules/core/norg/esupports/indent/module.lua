--[[
-- TODO
--]]

local module = neorg.modules.create("core.norg.esupports.indent")

module.setup = function()
    return {
        wants = {
            "core.integrations.treesitter",
            "core.autocommands",
        }
    }
end

module.public = {
    indentexpr = function()
        log.warn("Test")
    end
}

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
end

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" and event.content then
        vim.api.nvim_buf_set_option(event.buffer, "indentexpr", "v:lua.require('neorg.modules.core.norg.esupports.indent.module').public.indentexpr()")
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true
    }
}

return module
