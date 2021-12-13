--[[
--	HELPER FUNCTIONS FOR NEORG
--	This file contains some simple helper functions to improve QOL
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

    --- Parses a version string like "0.4.2" and provides back a table like { major = <number>, minor = <number>, patch = <number> }
    --- @param version_string string #The input string
    --- @return table #The parsed version string, or `nil` if a failure occurred during parsing
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
}

return neorg.utils
