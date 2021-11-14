--[[
--	HELPER FUNCTIONS FOR NEORG
--	This file contains some simple helper function improve quality of life
--]]

neorg.utils = {

    -- @Summary Gets the current system username
    -- @Description An OS agnostic way of querying the current user
    get_username = function()
        local current_os = require("neorg.config").os_info

        if not current_os then
            return current_os
        end

        if current_os == "linux" or current_os == "mac" then
            return os.getenv("USER")
        elseif current_os == "windows" then
            return os.getenv("username")
        end

        return ""
    end,

    -- @Summary Returns a list of languages supported by Neorg
    -- @Description Returns an array of strings, the array being a list of languages that Neorg can inject
    -- @Param  values (boolean) - if set to true will return an array of strings, if false will return a key-value table
    get_language_list = function(values)
        local ret = {
            ["bash"] = {},
            ["beancount"] = {},
            ["bibtex"] = {},
            ["c"] = {},
            ["c_sharp"] = {},
            ["clojure"] = {},
            ["cmake"] = {},
            ["comment"] = {},
            ["commonlisp"] = {},
            ["cpp"] = {},
            ["css"] = {},
            ["cuda"] = {},
            ["d"] = {},
            ["dart"] = {},
            ["devicetree"] = {},
            ["dockerfile"] = {},
            ["dot"] = {},
            ["elixir"] = {},
            ["elm"] = {},
            ["erlang"] = {},
            ["fennel"] = {},
            ["fish"] = {},
            ["fortran"] = {},
            ["gdscript"] = {},
            ["glimmer"] = {},
            ["glsl"] = {},
            ["go"] = {},
            ["gdresource"] = {},
            ["gomod"] = {},
            ["graphql"] = {},
            ["haskell"] = {},
            ["hcl"] = {},
            ["heex"] = {},
            ["hjson"] = {},
            ["html"] = {},
            ["java"] = {},
            ["javascript"] = {},
            ["jsdoc"] = {},
            ["json"] = {},
            ["json5"] = {},
            ["jsonc"] = {},
            ["julia"] = {},
            ["kotlin"] = {},
            ["latex"] = {},
            ["ledger"] = {},
            ["llvm"] = {},
            ["lua"] = {},
            ["nix"] = {},
            ["ocaml"] = {},
            ["ocaml_interface"] = {},
            ["ocamllex"] = {},
            ["perl"] = {},
            ["php"] = {},
            ["pioasm"] = {},
            ["python"] = {},
            ["ql"] = {},
            ["query"] = {},
            ["r"] = {},
            ["regex"] = {},
            ["rst"] = {},
            ["ruby"] = {},
            ["rust"] = {},
            ["scala"] = {},
            ["scss"] = {},
            ["sparql"] = {},
            ["supercollider"] = {},
            ["surface"] = {},
            ["svelte"] = {},
            ["swift"] = {},
            ["teal"] = {},
            ["tlaplus"] = {},
            ["toml"] = {},
            ["tsx"] = {},
            ["turtle"] = {},
            ["typescript"] = {},
            ["verilog"] = {},
            ["vim"] = {},
            ["vue"] = {},
            ["yaml"] = {},
            ["yang"] = {},
            ["zig"] = {},
        }

        if values then
            return vim.tbl_keys(ret)
        else
            return ret
        end
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

    --- Perform a backwards search for a character and return the index of that character
    --- @param str string #The string to search
    --- @param char string #The substring to search for
    --- @return number|nil #The index of the found substring or `nil` if not found
    rfind = function(str, char)
        local length = str:len()
        local found_from_back = str:reverse():find(char)
        return found_from_back and length - found_from_back
    end,

    is_minimum_version = function(major, minor, patch)
        local version = vim.version()

        return major <= version.major and minor <= version.minor and patch <= version.patch
    end,
}

neorg.lib = {
    match = function(statements)
        local item = statements[1]

        if not item then
            return
        end

        table.remove(statements, 1)

        local compare = statements[2] or function(lhs, rhs)
            return lhs == rhs
        end

        if statements[2] then
            table.remove(statements, 2)
        end

        for case, action in pairs(statements) do
            if compare(item, case) then
                local action_type = type(action)

                if action_type == "function" then
                    return action(item)
                end

                return action
            end
        end

        if statements.default then
            local action = statements.default
            local action_type = type(action)

            if action_type == "function" then
                return action(item)
            end

            return action
        end
    end,

    when = function(comparison, when_true, when_false)
        return neorg.lib.match({
            type(comparison) == "table" and unpack(comparison) or comparison,
            ["true"] = when_true,
            ["false"] = when_false,
        })
    end,

    map = function(tbl, callback)
        local copy = vim.deepcopy(tbl)

        for k, v in pairs(tbl) do
            local cb = callback(k, v)

            if cb then
                copy[k] = cb
            end
        end

        return copy
    end,

    filter = function(tbl, callback)
        for k, v in pairs(tbl) do
            local cb = callback(k, v)

            if cb then
                return cb
            end
        end
    end,

    find = function(tbl, element)
        return neorg.lib.filter(tbl, function(key, value)
            if value == element then
                return key
            end
        end)
    end,

    insert_or = function(tbl, value)
        local item = neorg.lib.find(tbl, value)

        return item and tbl[item]
            or (function()
                table.insert(tbl, value)
                return value
            end)()
    end,

    pick = function(tbl, values)
        local result = {}

        for _, value in ipairs(values) do
            if tbl[value] then
                table.insert(result, tbl[value])
            end
        end

        return result
    end,

    wrap = function(function_pointer, ...)
        local params = { ... }

        return function()
            return function_pointer(unpack(params))
        end
    end,

    add = function(amount)
        return function(value)
            return value + amount
        end
    end,

    reparg = function(value, index)
        if index == 1 then
            return value
        end

        return value, neorg.lib.reparg(value, index - 1)
    end,
}

return neorg.utils
