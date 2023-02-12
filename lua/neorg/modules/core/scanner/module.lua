--[[
    file: Scanner-Module
    title: Scanner module for Neorg
    summary: This module is an implementation of a scanner that can be used anywhere TS can't be used.
    internal: true
    ---
This module is an implementation of a scanner that can be used anywhere TS can't be used.
It is not currently used anywhere, and is small enough to be self-documenting.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.scanner")

---@class core.scanner
module.public = {
    initialize_new = function(self, source)
        self:end_session()
        self.source = source
    end,

    end_session = function(self)
        local tokens = self.tokens

        self.position = 0
        self.buffer = ""
        self.source = ""
        self.tokens = {}

        return tokens
    end,

    position = 0,
    buffer = "",
    source = "",
    tokens = {},

    current = function(self)
        if self.position == 0 then
            return nil
        end
        return self.source:sub(self.position, self.position)
    end,

    lookahead = function(self, count)
        count = count or 1

        if self.position + count > self.source:len() then
            return nil
        end

        return self.source:sub(self.position + count, self.position + count)
    end,

    lookbehind = function(self, count)
        count = count or 1

        if self.position - count < 0 then
            return nil
        end

        return self.source:sub(self.position - count, self.position - count)
    end,

    backtrack = function(self, amount)
        self.position = self.position - amount
    end,

    advance = function(self)
        self.buffer = self.buffer .. self.source:sub(self.position, self.position)
        self.position = self.position + 1
    end,

    skip = function(self)
        self.position = self.position + 1
    end,

    mark_end = function(self)
        if self.buffer:len() ~= 0 then
            table.insert(self.tokens, self.buffer)
            self.buffer = ""
        end
    end,

    halt = function(self, mark_end, continue_till_end)
        if mark_end then
            self:mark_end()
        end

        if continue_till_end then
            self.buffer = self.source:sub(self.position + 1)
            self:mark_end()
        end

        self.position = self.source:len() + 1
    end,
}

return module
