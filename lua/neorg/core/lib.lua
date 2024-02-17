local lib = {}

--- Returns the item that matches the first item in statements.
--- @param value any The value to compare against.
--- @param compare? fun(lhs: any, rhs: any): boolean A custom comparison function.
--- @return fun(statements: table<any, any>): any # A function to invoke with a table of potential matches.
function lib.match(value, compare)
    -- Returning a function allows for such syntax:
    -- match(something) { ..matches.. }
    return function(statements)
        if value == nil then
            return
        end

        -- Set the comparison function
        -- A comparison function may be required for more complex
        -- data types that need to be compared against another static value.
        -- The default comparison function compares booleans as strings to ensure
        -- that boolean comparisons work as intended.
        compare = compare
            or function(lhs, rhs)
                if type(lhs) == "boolean" then
                    return tostring(lhs) == rhs
                end

                return lhs == rhs
            end

        -- Go through every statement, compare it, and perform the desired action
        -- if the comparison was successful
        for case, action in pairs(statements) do
            -- If the case statement is a list of data then compare that
            if type(case) == "table" and vim.tbl_islist(case) then
                for _, subcase in ipairs(case) do
                    if compare(value, subcase) then
                        -- The action can be a function, in which case it is invoked
                        -- and the return value of that function is returned instead.
                        if type(action) == "function" then
                            return action(value)
                        end

                        return action
                    end
                end
            end

            if compare(value, case) then
                -- The action can be a function, in which case it is invoked
                -- and the return value of that function is returned instead.
                if type(action) == "function" then
                    return action(value)
                end

                return action
            end
        end

        -- If we've fallen through all statements to check and haven't found
        -- a single match then see if we can fall back to a `_` clause instead.
        if statements._ then
            local action = statements._

            if type(action) == "function" then
                return action(value)
            end

            return action
        end
    end
end

--- Wrapped around `match()` that performs an action based on a condition.
--- @param comparison boolean The comparison to perform.
--- @param when_true function|any The value to return when `comparison` is true.
--- @param when_false function|any The value to return when `comparison` is false.
--- @return any # The value that either `when_true` or `when_false` returned.
--- @see neorg.core.lib.match
function lib.when(comparison, when_true, when_false)
    if type(comparison) ~= "boolean" then
        comparison = (comparison ~= nil)
    end

    return lib.match(type(comparison) == "table" and unpack(comparison) or comparison)({
        ["true"] = when_true,
        ["false"] = when_false,
    })
end

--- Maps a function to every element of a table.
--- The function can return a value, in which case that specific element will be assigned
--- the return value of that function.
--- @generic K, V
--- @param tbl table<K, V> The table to iterate over
--- @param callback fun(key: K, value: V, tbl: table<K, V>): any? The callback that should be invoked on every iteration
--- @deprecated please use Neovim's `vim.iter` API instead
--- @return table # A modified version of the original `tbl`.
function lib.map(tbl, callback)
    local copy = vim.deepcopy(tbl)

    for k, v in pairs(tbl) do
        local cb = callback(k, v, tbl)

        if cb then
            copy[k] = cb
        end
    end

    return copy
end

--- Iterates over all elements of a table and returns the first value returned by the callback.
--- @generic K, V
--- @param tbl table<K, V> The table to iterate over.
--- @param callback fun(key: K, value: V): V? The callback function that should be invoked on each iteration. Can return a value in which case that value will be returned from the `filter()` call.
--- @return V? # The value returned by `callback`, if any.
function lib.filter(tbl, callback)
    for k, v in pairs(tbl) do
        local cb = callback(k, v)

        if cb then
            return cb
        end
    end
end

--- Finds any key in an array.
--- @generic V
--- @param tbl { [number]: V } An array of values to iterate over.
--- @param element V The item to find.
--- @return V? # The found value or `nil` if nothing could be found.
function lib.find(tbl, element)
    return lib.filter(tbl, function(key, value)
        if value == element then
            return key
        end
    end)
end

--- Inserts a value into a table if it doesn't exist, else returns the existing value.
--- @param tbl table The table to insert into.
--- @param value any The value to insert.
--- @return `value` # The item to return.
function lib.insert_or(tbl, value)
    local item = lib.find(tbl, value)

    return item and tbl[item] or (function()
        table.insert(tbl, value)
        return value
    end)()
end

--- Picks a set of values from a table and returns them in an array.
--- @param tbl table The table to extract the keys from.
--- @param values string[] An array of strings, these being the keys you'd like to extract.
--- @return any # The picked values from the table.
function lib.pick(tbl, values)
    local result = {}

    for _, value in ipairs(values) do
        if tbl[value] then
            table.insert(result, tbl[value])
        end
    end

    return result
end

--- Tries to extract a variable in all nesting levels of a table.
--- @param tbl table The table to traverse.
--- @param value any The value to look for - note that comparison is done through the `==` operator.
--- @return any? # The value if it was found, else nil.
function lib.extract(tbl, value)
    local results = {}

    for key, expected_value in pairs(tbl) do
        if key == value then
            table.insert(results, expected_value)
        end

        if type(expected_value) == "table" then
            vim.list_extend(results, lib.extract(expected_value, value))
        end
    end

    return results
end

--- Wraps a conditional "not" function in a callback.
--- @param cb function The function to wrap
--- @param ... any The arguments to pass to the wrapped function
--- @return function # The wrapped function in a callback
function lib.wrap_cond_not(cb, ...)
    local params = { ... }
    return function(v)
        return not cb(v, unpack(params))
    end
end

--- Wraps a conditional function in a callback.
--- @param cb function The function to wrap.
--- @param ... any The arguments to pass to the wrapped function.
--- @return function # The wrapped function in a callback.
function lib.wrap_cond(cb, ...)
    local params = { ... }
    return function(v)
        return cb(v, unpack(params))
    end
end

--- Wraps a function in a callback.
--- @generic T: function, A
--- @param function_pointer T The function to wrap.
--- @param ... A The arguments to pass to the wrapped function.
--- @return fun(...: A): T # The wrapped function in a callback.
function lib.wrap(function_pointer, ...)
    local params = { ... }

    if type(function_pointer) ~= "function" then
        local prev = function_pointer

        -- luacheck: push ignore
        function_pointer = function()
            return prev, unpack(params)
        end
        -- luacheck: pop
    end

    return function()
        return function_pointer(unpack(params))
    end
end

--- Repeats an arguments `index` amount of times.
--- @generic T
--- @param value T The value to repeat.
--- @param index number The amount of times to repeat the argument.
--- @return T ... # An expanded vararg with the repeated argument.
function lib.reparg(value, index)
    if index == 1 then
        return value
    end

    return value, lib.reparg(value, index - 1)
end

--- Lazily concatenates a string to prevent runtime errors where an object may not exist
--- Consider the following example:
---
---     lib.when(str ~= nil, str .. " extra text", "")
---
--- This would fail, simply because the string concatenation will still be evaluated in order
--- to be placed inside the variable. You may use:
---
---     lib.when(str ~= nil, lib.lazy_string_concat(str, " extra text"), "")
---
--- To mitigate this issue directly.
--- @param ... string An unlimited number of strings.
--- @return string # The result of all the strings concatenated.
function lib.lazy_string_concat(...)
    return table.concat({ ... })
end

--- Converts an array of values to a table of keys
--- @generic K, V
--- @param values K[] An array of values to store as keys.
--- @param default V The default value to assign to all key pairs.
--- @return { [K]: V } # The converted table.
function lib.to_keys(values, default)
    local ret = {}

    for _, value in ipairs(values) do
        ret[value] = default or {}
    end

    return ret
end

--- Constructs a new key-pair table by running a callback on all elements of an array.
--- @param keys string[] A string array with the keys to iterate over.
--- @param cb fun(key: string): any? A function that gets invoked with each key and returns a value to be placed in the output table.
--- @return table # The newly constructed table.
function lib.construct(keys, cb)
    local result = {}

    for _, key in ipairs(keys) do
        result[key] = cb(key)
    end

    return result
end

--- If `val` is a function, executes it with the desired arguments, else just returns `val`.
--- @param val function|any Either a function or any other value.
--- @param ... any Potential arguments to give `val` if it is a function.
--- @return any # The returned evaluation of `val`.
function lib.eval(val, ...)
    if type(val) == "function" then
        return val(...)
    end

    return val
end

--- Extends a list by constructing a new one vs mutating an existing
--- list in the case of `vim.list_extend`.
--- @param list any[] The list to extend.
--- @param ... any[]  A set of lists to expand the current list by.
--- @return any[] # The lists concatenated to each other.
function lib.list_extend(list, ...)
    return list and { unpack(list), unpack(lib.list_extend(...)) } or {}
end

--- Converts a table with `key = value` pairs to a `{ key, value }` array.
--- @generic K, V
--- @param tbl_with_keys table<K, V> A table with key-value pairs.
--- @return { [number]: { [0]: K, [1]: V } } # An array of `{ key, value }` pairs.
function lib.unroll(tbl_with_keys)
    local res = {}

    for key, value in pairs(tbl_with_keys) do
        table.insert(res, { key, value })
    end

    return res
end

--- Works just like pcall, except returns only a single value or nil (useful for ternary operations
--- which are not possible with a function like `pcall` that returns two values).
--- @generic T
--- @param func fun(...: any): T The function to invoke in a protected environment.
--- @param ... any The parameters to pass to `func`.
--- @return T? # The return value of the executed function or `nil`.
function lib.inline_pcall(func, ...)
    local ok, ret = pcall(func, ...)

    if ok then
        return ret
    end

    -- return nil
end

--- Perform a backwards search for a character and return the index of that character.
--- @param str string The string to search.
--- @param char string The substring to search for.
--- @return number? # The index of the found substring or `nil` if not found.
function lib.rfind(str, char)
    local length = str:len()
    local found_from_back = str:reverse():find(char)
    return found_from_back and length - found_from_back
end

--- Ensure that a nested set of variables exists.
--- Useful when you want to initialise a chain of nested values before writing to them.
--- @param tbl table The table you want to modify.
--- @param ... string A list of indices to recursively nest into.
function lib.ensure_nested(tbl, ...)
    local ref = tbl or {}

    for _, key in ipairs({ ... }) do
        ref[key] = ref[key] or {}
        ref = ref[key]
    end
end

--- Capitalizes the first letter of each word in a given string.
--- @param str string The string to capitalize.
--- @return string # The capitalized string.
function lib.title(str)
    local result = {}

    for word in str:gmatch("[^%s]+") do
        local lower = word:sub(2):lower()

        table.insert(result, word:sub(1, 1):upper() .. lower)
    end
    return table.concat(result, " ")
end

--- Wraps a number so that it fits within a given range.
--- @param value number The number to wrap.
--- @param min number The lower bound.
--- @param max number The higher bound.
--- @return number # The wrapped number, guarantees `min <= value <= max`.
function lib.number_wrap(value, min, max)
    local range = max - min + 1
    local wrapped_value = ((value - min) % range) + min

    if wrapped_value < min then
        wrapped_value = wrapped_value + range
    end

    return wrapped_value
end

--- Split a path into its components.
--- Example: `/my/cool/path/file.txt` --> `{ my, cool, path, file.txt }`
--- @param path string The path to split.
--- @return string[] # The path components.
function lib.tokenize_path(path)
    local tokens = {}
    for capture in path:gmatch("[^/\\]+") do
        table.insert(tokens, capture)
    end
    return tokens
end

lib.mod = {}

--- Wrapper function to add two values.
--- This function only takes in one argument because the second value to add is provided as a parameter in the callback.
--- @param amount number The number to add.
--- @return fun(_, value: number): number # A callback adding the static value to the dynamic amount.
function lib.mod.add(amount)
    return function(_, value)
        return value + amount
    end
end

--- Wrapper function to set a value to another value in a `map` sequence.
--- @generic T
--- @param to T A static value to set each element of the table to.
--- @return fun(): T # A callback that returns the static value
function lib.mod.modify(to)
    return function()
        return to
    end
end

lib.mod.exclude = {}

function lib.mod.exclude.first(func, alt)
    return function(i, val)
        return i == 1 and (alt and alt(i, val) or val) or func(i, val)
    end
end

function lib.mod.exclude.last(func, alt)
    return function(i, val, tbl)
        return next(tbl, i) and func(i, val) or (alt and alt(i, val) or val)
    end
end

return lib
