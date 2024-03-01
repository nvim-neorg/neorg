-- log.lua
--
-- Inspired by rxi/log.lua
-- Modified by tjdevries and can be found at github.com/tjdevries/vlog.nvim
-- Modified again by Vhyrro for use with neorg :)
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.

local lib = require("lua-utils")

--- @alias LogLevel
--- | "trace"
--- | "debug"
--- | "info"
--- | "warn"
--- | "error"
--- | "fatal"

--- @class (exact) neorg.log.configuration
--- @field plugin string                                           Name of the plugin. Prepended to log messages.
--- @field use_console boolean                                     Whether to print the output to Neovim while running.
--- @field highlights boolean                                      Whether highlighting should be used in console (using `:echohl`).
--- @field use_file boolean                                        Whether to write output to a file.
--- @field level LogLevel                                          Any messages above this level will be logged.
--- @field modes ({ name: LogLevel, hl: string, level: number })[] Level configuration.
--- @field float_precision number                                  Can limit the number of decimals displayed for floats.

--- User configuration section
--- @type neorg.log.configuration
local default_config = {
    plugin = "neorg",

    use_console = true,

    highlights = true,

    use_file = true,

    level = "warn",

    modes = {
        { name = "trace", hl = "Comment", level = vim.log.levels.TRACE },
        { name = "debug", hl = "Comment", level = vim.log.levels.DEBUG },
        { name = "info", hl = "None", level = vim.log.levels.INFO },
        { name = "warn", hl = "WarningMsg", level = vim.log.levels.WARN },
        { name = "error", hl = "ErrorMsg", level = vim.log.levels.ERROR },
        { name = "fatal", hl = "ErrorMsg", level = 5 },
    },

    float_precision = 0.01,
}

-- {{{ NO NEED TO CHANGE
local log = {}

log.get_default_config = function()
    return default_config
end

local unpack = unpack or table.unpack

--- @param config neorg.log.configuration
--- @param standalone boolean
log.new = function(config, standalone)
    config = vim.tbl_deep_extend("force", default_config, config)
    config.plugin = "neorg" -- Force the plugin name to be neorg

    local outfile = string.format("%s/%s.log", vim.api.nvim_call_function("stdpath", { "data" }), config.plugin)

    local obj = lib.match(standalone ~= nil)({
        ["true"] = log,
        ["false"] = {},
    })

    local levels = {}
    for _, v in ipairs(config.modes) do
        levels[v.name] = v.level
    end

    local round = function(x, increment)
        increment = increment or 1
        x = x / increment
        return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
    end

    local make_string = function(...)
        local t = {}
        for i = 1, select("#", ...) do
            local x = select(i, ...)

            if type(x) == "number" and config.float_precision then
                x = tostring(round(x, config.float_precision))
            elseif type(x) == "table" then
                x = vim.inspect(x)
            else
                x = tostring(x)
            end

            t[#t + 1] = x
        end
        return table.concat(t, " ")
    end

    local log_at_level = function(level_config, message_maker, ...)
        -- Return early if we"re below the config.level
        if levels[level_config.name] < levels[config.level] then
            return
        end
        local nameupper = level_config.name:upper()

        local msg = message_maker(...)
        local info = debug.getinfo(2, "Sl")
        local lineinfo = info.short_src .. ":" .. info.currentline

        -- Output to console
        if config.use_console then
            local v = string.format("(%s)\n%s\n%s", os.date("%H:%M:%S"), lineinfo, msg)

            if config.highlights and level_config.hl then
                (vim.schedule_wrap(function()
                    vim.cmd(string.format("echohl %s", level_config.hl))
                end))()
            end

            (vim.schedule_wrap(function()
                vim.notify(string.format("[%s] %s", config.plugin, vim.fn.escape(v, '"')), level_config.level)
                -- vim.cmd(string.format([[echom "[%s] %s"]], config.plugin, vim.fn.escape(v, '"')))
            end))()

            if config.highlights and level_config.hl then
                (vim.schedule_wrap(function()
                    vim.cmd("echohl NONE")
                end))()
            end
        end

        -- Output to log file
        if config.use_file then
            local fp = assert(io.open(outfile, "a"))
            local str = string.format("[%-6s%s] %s: %s\n", nameupper, os.date(), lineinfo, msg)
            fp:write(str)
            fp:close()
        end
    end

    for _, x in ipairs(config.modes) do
        obj[x.name] = function(...)
            return log_at_level(x, make_string, ...)
        end

        obj[("fmt_%s"):format(x.name)] = function()
            return log_at_level(x, function(...)
                local passed = { ... }
                local fmt = table.remove(passed, 1)
                local inspected = {}
                for _, v in ipairs(passed) do
                    table.insert(inspected, vim.inspect(v))
                end
                return string.format(fmt, unpack(inspected))
            end)
        end
    end
end

-- }}}

return log
