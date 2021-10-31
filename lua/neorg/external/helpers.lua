--[[
--	HELPER FUNCTIONS FOR NEORG
--	This file contains some simple helper function improve quality of life
--]]

neorg.utils = {

    ---Render folded text.
    ---Support showing heading icons
    ---@return string
    foldtext = function()
        local line = vim.fn.getline(vim.v.foldstart)
        local _, count = string.gsub(line, "%*", "")
        if count ~= 0 then
            local config = require("neorg.modules.core.norg.concealer.module").config.public.icons.heading
            local icon = config["level_" .. count].icon
            line = line:gsub(("%*"):rep(count), icon)
        end

        local res = line:gsub([[\\t]], ([[\ ]]):rep(vim.o.tabstop)) .. " …"

        return res
    end,

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
            ["go"] = {},
            ["gdresource"] = {},
            ["gomod"] = {},
            ["graphql"] = {},
            ["haskell"] = {},
            ["hcl"] = {},
            ["heex"] = {},
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
            ["lua"] = {},
            ["nix"] = {},
            ["ocaml"] = {},
            ["ocaml_interface"] = {},
            ["ocamllex"] = {},
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

return neorg.utils
