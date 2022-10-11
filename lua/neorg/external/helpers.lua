--[[
--    HELPER FUNCTIONS FOR NEORG
--    This file contains some simple helper functions to improve QOL
--]]

neorg.utils = {

    --- An OS agnostic way of querying the current user
    get_username = function()
        local current_os = require("neorg.config").os_info

        if not current_os then
            return ""
        end

        if current_os == "linux" or current_os == "mac" then
            return os.getenv("USER") or ""
        elseif current_os == "windows" then
            return os.getenv("username") or ""
        end

        return ""
    end,

    --- Returns an array of strings, the array being a list of languages that Neorg can inject
    ---@param values boolean #If set to true will return an array of strings, if false will return a key-value table
    get_language_list = function(values)
        local regex_files = {}
        local ts_files = {}
        -- search for regex files in syntax and after/syntax
        -- its best if we strip out anything but the ft name
        for _, lang in pairs(vim.api.nvim_get_runtime_file("syntax/*.vim", true)) do
            local lang_name = vim.fn.fnamemodify(lang, ":t:r")
            table.insert(regex_files, lang_name)
        end
        for _, lang in pairs(vim.api.nvim_get_runtime_file("after/syntax/*.vim", true)) do
            local lang_name = vim.fn.fnamemodify(lang, ":t:r")
            table.insert(regex_files, lang_name)
        end
        -- search for available parsers
        for _, parser in pairs(vim.api.nvim_get_runtime_file("parser/*.so", true)) do
            local parser_name = vim.fn.fnamemodify(parser, ":t:r")
            ts_files[parser_name] = true
        end
        local ret = {}

        for _, syntax in pairs(regex_files) do
            if ts_files[syntax] then
                ret[syntax] = { type = "treesitter" }
            else
                ret[syntax] = { type = "syntax" }
            end
        end

        return values and vim.tbl_keys(ret) or ret
    end,

    get_language_shorthands = function(reverse_lookup)
        local langs = {
            ["bash"] = { "sh", "zsh" },
            ["c_sharp"] = { "csharp", "cs" },
            ["clojure"] = { "clj" },
            ["cmake"] = { "cmake.in" },
            ["commonlisp"] = { "cl" },
            ["cpp"] = { "hpp", "cc", "hh", "c++", "h++", "cxx", "hxx" },
            ["dockerfile"] = { "docker" },
            ["erlang"] = { "erl" },
            ["fennel"] = { "fnl" },
            ["fortran"] = { "f90", "f95" },
            ["go"] = { "golang" },
            ["godot"] = { "gdscript" },
            ["gomod"] = { "gm" },
            ["haskell"] = { "hs" },
            ["java"] = { "jsp" },
            ["javascript"] = { "js", "jsx" },
            ["julia"] = { "julia-repl" },
            ["kotlin"] = { "kt" },
            ["python"] = { "py", "gyp" },
            ["ruby"] = { "rb", "gemspec", "podspec", "thor", "irb" },
            ["rust"] = { "rs" },
            ["supercollider"] = { "sc" },
            ["typescript"] = { "ts" },
            ["verilog"] = { "v" },
            ["yaml"] = { "yml" },
        }

        return reverse_lookup and vim.tbl_add_reverse_lookup(langs) or langs
    end,

    --- Checks whether Neovim is running at least at a specific version
    ---@param major number #The major release of Neovim
    ---@param minor number #The minor release of Neovim
    ---@param patch number #The patch number (in case you need it)
    ---@return boolean #Whether Neovim is running at the same or a higher version than the one given
    is_minimum_version = function(major, minor, patch)
        local version = vim.version()

        return major <= version.major and minor <= version.minor and patch <= version.patch
    end,

    --- Parses a version string like "0.4.2" and provides back a table like { major = <number>, minor = <number>, patch = <number> }
    ---@param version_string string #The input string
    ---@return table #The parsed version string, or `nil` if a failure occurred during parsing
    parse_version_string = function(version_string)
        if not version_string then
            return
        end

        -- Define variables that split the version up into 3 slices
        local split_version, versions, ret =
            vim.split(version_string, ".", true), { "major", "minor", "patch" }, { major = 0, minor = 0, patch = 0 }

        -- If the sliced version string has more than 3 elements error out
        if #split_version > 3 then
            log.warn(
                "Attempt to parse version:",
                version_string,
                "failed - too many version numbers provided. Version should follow this layout: <major>.<minor>.<patch>"
            )
            return
        end

        -- Loop through all the versions and check whether they are valid numbers. If they are, add them to the return table
        for i, ver in ipairs(versions) do
            if split_version[i] then
                local num = tonumber(split_version[i])

                if not num then
                    log.warn("Invalid version provided, string cannot be converted to integral type.")
                    return
                end

                ret[ver] = num
            end
        end

        return ret
    end,

    get_filetype = function(file, force_filetype)
        local filetype = force_filetype

        -- Getting a filetype properly is... difficult
        -- This is why we leverage Neovim instead.
        -- We create a dummy buffer with the filepath the user wanted to export to
        -- and query the filetype from there.
        if not filetype then
            local dummy_buffer = vim.uri_to_bufnr(vim.uri_from_fname(file))
            vim.fn.bufload(dummy_buffer)
            filetype = vim.api.nvim_buf_get_option(dummy_buffer, "filetype")
            vim.api.nvim_buf_delete(dummy_buffer, { force = true })
        end

        return filetype
    end,
}

neorg.lib = {
    --- Returns the item that matches the first item in statements
    ---@param value any #The value to compare against
    ---@param compare? function #A custom comparison function
    ---@return function #A function to invoke with a table of potential matches
    match = function(value, compare)
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
    end,

    --- Wrapped around `match()` that performs an action based on a condition
    ---@param comparison boolean #The comparison to perform
    ---@param when_true function|any #The value to return when `comparison` is true
    ---@param when_false function|any #The value to return when `comparison` is false
    ---@return any #The value that either `when_true` or `when_false` returned
    when = function(comparison, when_true, when_false)
        if type(comparison) ~= "boolean" then
            comparison = (comparison ~= nil)
        end

        return neorg.lib.match(type(comparison) == "table" and unpack(comparison) or comparison)({
            ["true"] = when_true,
            ["false"] = when_false,
        })
    end,

    --- Maps a function to every element of a table
    --  The function can return a value, in which case that specific element will be assigned
    --  the return value of that function.
    ---@param tbl table #The table to iterate over
    ---@param callback function #The callback that should be invoked on every iteration
    ---@return table #A modified version of the original `tbl`.
    map = function(tbl, callback)
        local copy = vim.deepcopy(tbl)

        for k, v in pairs(tbl) do
            local cb = callback(k, v, tbl)

            if cb then
                copy[k] = cb
            end
        end

        return copy
    end,

    --- Iterates over all elements of a table and returns the first value returned by the callback.
    ---@param tbl table #The table to iterate over
    ---@param callback function #The callback function that should be invoked on each iteration.
    --- Can return a value in which case that value will be returned from the `filter()` call.
    ---@return any|nil #The value returned by `callback`, if any
    filter = function(tbl, callback)
        for k, v in pairs(tbl) do
            local cb = callback(k, v)

            if cb then
                return cb
            end
        end
    end,

    --- Finds any key in an array
    ---@param tbl array #An array of values to iterate over
    ---@param element any #The item to find
    ---@return any|nil #The found value or `nil` if nothing could be found
    find = function(tbl, element)
        return neorg.lib.filter(tbl, function(key, value)
            if value == element then
                return key
            end
        end)
    end,

    --- Inserts a value into a table if it doesn't exist, else returns the existing value.
    ---@param tbl table #The table to insert into
    ---@param value number|string #The value to insert
    ---@return any #The item to return
    insert_or = function(tbl, value)
        local item = neorg.lib.find(tbl, value)

        return item and tbl[item]
            or (function()
                table.insert(tbl, value)
                return value
            end)()
    end,

    --- Picks a set of values from a table and returns them in an array
    ---@param tbl table #The table to extract the keys from
    ---@param values array[string] #An array of strings, these being the keys you'd like to extract
    ---@return array[any] #The picked values from the table
    pick = function(tbl, values)
        local result = {}

        for _, value in ipairs(values) do
            if tbl[value] then
                table.insert(result, tbl[value])
            end
        end

        return result
    end,

    --- Tries to extract a variable in all nesting levels of a table.
    ---@param tbl table #The table to traverse
    ---@param value any #The value to look for - note that comparison is done through the `==` operator
    ---@return any|nil #The value if it was found, else nil
    extract = function(tbl, value)
        local results = {}

        for key, expected_value in pairs(tbl) do
            if key == value then
                table.insert(results, expected_value)
            end

            if type(expected_value) == "table" then
                vim.list_extend(results, neorg.lib.extract(expected_value, value))
            end
        end

        return results
    end,

    --- Wraps a conditional "not" function in a vim.tbl callback
    ---@param cb function #The function to wrap
    ---@vararg ... #The arguments to pass to the wrapped function
    ---@return function #The wrapped function in a vim.tbl callback
    wrap_cond_not = function(cb, ...)
        local params = { ... }
        return function(v)
            return not cb(v, unpack(params))
        end
    end,

    --- Wraps a conditional function in a vim.tbl callback
    ---@param cb function #The function to wrap
    ---@vararg ... #The arguments to pass to the wrapped function
    ---@return function #The wrapped function in a vim.tbl callback
    wrap_cond = function(cb, ...)
        local params = { ... }
        return function(v)
            return cb(v, unpack(params))
        end
    end,

    --- Wraps a function in a callback
    ---@param function_pointer function #The function to wrap
    ---@vararg ... #The arguments to pass to the wrapped function
    ---@return function #The wrapped function in a callback
    wrap = function(function_pointer, ...)
        local params = { ... }

        if type(function_pointer) ~= "function" then
            local prev = function_pointer

            -- luacheck: push ignore
            function_pointer = function(...)
                return prev, unpack(params)
            end
            -- luacheck: pop
        end

        return function()
            return function_pointer(unpack(params))
        end
    end,

    --- Modifiers for the `map` function
    mod = {
        --- Wrapper function to add two values
        --  This function only takes in one argument because the second value
        --  to add is provided as a parameter in the callback.
        ---@param amount number #The number to add
        ---@return function #A callback adding the static value to the dynamic amount
        add = function(amount)
            return function(_, value)
                return value + amount
            end
        end,

        --- Wrapper function to set a value to another value in a `map` sequence
        ---@param to any #A static value to set each element of the table to
        ---@return function #A callback that returns the static value
        modify = function(to)
            return function()
                return to
            end
        end,

        --- Filtering modifiers that exclude certain elements from a table
        exclude = {
            first = function(func, alt)
                return function(i, val)
                    return i == 1 and (alt and alt(i, val) or val) or func(i, val)
                end
            end,

            last = function(func, alt)
                return function(i, val, tbl)
                    return next(tbl, i) and func(i, val) or (alt and alt(i, val) or val)
                end
            end,
        },
    },

    --- Repeats an arguments `index` amount of times
    ---@param value any #The value to repeat
    ---@param index number #The amount of times to repeat the argument
    ---@return ... #An expanded vararg with the repeated argument
    reparg = function(value, index)
        if index == 1 then
            return value
        end

        return value, neorg.lib.reparg(value, index - 1)
    end,

    --- Lazily concatenates a string to prevent runtime errors where an object may not exist
    --  Consider the following example:
    --
    --      neorg.lib.when(str ~= nil, str .. " extra text", "")
    --
    --  This would fail, simply because the string concatenation will still be evaluated in order
    --  to be placed inside the variable. You may use:
    --
    --      neorg.lib.when(str ~= nil, neorg.lib.lazy_string_concat(str, " extra text"), "")
    --
    --  To mitigate this issue directly.
    --- @vararg string #An unlimited number of strings
    ---@return string #The result of all the strings concatenateA.
    lazy_string_concat = function(...)
        return table.concat({ ... })
    end,

    --- Converts an array of values to a table of keys
    ---@param values string[]|number[] #An array of values to store as keys
    ---@param default any #The default value to assign to all key pairs
    ---@return table #The converted table
    to_keys = function(values, default)
        local ret = {}

        for _, value in ipairs(values) do
            ret[value] = default or {}
        end

        return ret
    end,

    --- Constructs a new key-pair table by running a callback on all elements of an array.
    ---@param keys string[] #A string array with the keys to iterate over
    ---@param cb function #A function that gets invoked with each key and returns a value to be placed in the output table
    ---@return table #The newly constructed table
    construct = function(keys, cb)
        local result = {}

        for _, key in ipairs(keys) do
            result[key] = cb(key)
        end

        return result
    end,

    --- If `val` is a function, executes it with the desired arguments, else just returns `val`
    ---@param val any|function #Either a function or any other value
    ---@vararg any #Potential arguments to give `val` if it is a function
    ---@return any #The returned evaluation of `val`
    eval = function(val, ...)
        if type(val) == "function" then
            return val(...)
        end

        return val
    end,

    --- Extends a list by constructing a new one vs mutating an existing
    --  list in the case of `vim.list_extend`
    list_extend = function(list, ...)
        return list and { unpack(list), unpack(neorg.lib.list_extend(...)) } or {}
    end,

    --- Converts a table with `key = value` pairs to a `{ key, value }` array.
    ---@param tbl_with_keys table #A table with key-value pairs
    ---@return array #An array of `{ key, value }` pairs.
    unroll = function(tbl_with_keys)
        local res = {}

        for key, value in pairs(tbl_with_keys) do
            table.insert(res, { key, value })
        end

        return res
    end,

    --- Works just like pcall, except returns only a single value or nil (useful for ternary operations
    --  which are not possible with a function like `pcall` that returns two values).
    ---@param func function #The function to invoke in a protected environment
    ---@vararg any #The parameters to pass to `func`
    ---@return any|nil #The return value of the executed function or `nil`
    inline_pcall = function(func, ...)
        local ok, ret = pcall(func, ...)

        if ok then
            return ret
        end

        -- return nil
    end,

    --- Perform a backwards search for a character and return the index of that character
    ---@param str string #The string to search
    ---@param char string #The substring to search for
    ---@return number|nil #The index of the found substring or `nil` if not found
    rfind = function(str, char)
        local length = str:len()
        local found_from_back = str:reverse():find(char)
        return found_from_back and length - found_from_back
    end,
}

return neorg.utils
