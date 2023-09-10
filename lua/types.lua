---@meta


-- Pure data structure types
--------------------------------------------------------------------------------

--- Shorthand type for string-keyed tables
---@class dict<T>: { [string]: T }

--- Shorthand for integer-keyed tables, commonly known as arrays
---@class array<T>: { [integer]: T }
--- NOTE: As of the time of writing, LuaLS hasn't implemented static arrays.
--- You can use the `array` class for the time being, but leave a note when
--- the object should have a fixed size. For example, if an array object will
--- always have three strings, you can leave a note typing it this way:
---     string[3]
--- See: https://github.com/sumneko/lua-language-server/issues/1081


-- Types inherited from Vim's API
--------------------------------------------------------------------------------

---@class cursor_pos: array<integer>
---@see nvim_win_get_cursor
--- NOTE: integer[2]
