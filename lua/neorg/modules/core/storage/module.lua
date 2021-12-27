--[[
    File: Storage
    Title: Store persistent data and query it easily with `core.storage`
    Summary: Deals with storing persistent data across Neorg sessions.
    ---
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.storage")

module.setup = function()
    return {
        requires = {
            "core.autocommands",
        },
    }
end

module.config.public = {
    -- Full path to store data (saved in mpack data format)
    path = vim.fn.stdpath("data") .. "/neorg.mpack",
}

module.private = {
    data = {},
}

---@class core.storage
module.public = {
    sync = function()
        local file = io.open(module.config.public.path, "r")

        if not file then
            return
        end

        local content = file:read("*a")

        io.close(file)

        module.private.data = vim.mpack.decode and vim.mpack.decode(content) or vim.mpack.unpack(content)
    end,

    store = function(key, data)
        module.private.data[key] = data
    end,

    remove = function(key)
        module.private.data[key] = nil
    end,

    retrieve = function(key)
        return module.private.data[key] or {}
    end,

    flush = function()
        local file = io.open(module.config.public.path, "w")

        if not file then
            return
        end

        file:write(vim.mpack.encode and vim.mpack.encode(module.private.data) or vim.mpack.pack(module.private.data))

        io.close(file)
    end,
}

module.on_event = function(event)
    if event.type == "core.autocommands.events.vimleavepre" then
        module.public.flush()
    end
end

module.load = function()
    module.required["core.autocommands"].enable_autocommand("VimLeavePre")

    module.public.sync()
end

module.events.subscribed = {
    ["core.autocommands"] = {
        vimleavepre = true,
    },
}

return module
