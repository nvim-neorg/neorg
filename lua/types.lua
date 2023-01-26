---@meta


-- Pure data structure types
--------------------------------------------------------------------------------

--- Shorthand type for string-keyed dictionary
---@class dict<T>: { [string]: T }

--- NOTE: https://github.com/sumneko/lua-language-server/issues/1081
--- When merged, change as many vecs to the following tuple class definition
--- and remember to add an `@` before `class` :p
--- class tuple<T,N>: T[N]

--- Shorthand for integer-keyed dictionary aka vector
---@class vec<T>: { [integer]: T }


-- Types inherited from Vim's API
--------------------------------------------------------------------------------

---@class cursor_pos: vec<integer>
---@see nvim_win_get_cursor
--- NOTE:tuple<integer,2>
