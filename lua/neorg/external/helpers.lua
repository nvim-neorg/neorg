--[[
--	HELPER FUNCTIONS FOR NEORG
--	This file contains some simple helper function improve quality of life
--]]

neorg.utils = {
    -- @Summary Requires a file from the context of the current module
    -- @Description Allows the module creator to require a file from within the module's cwd
    -- @Param  module (table) - the module creator's module
    -- @Param  filename (string) - a path to the file
    require = function(module, filename)
        -- TODO: Explain this
        local new_module = vim.tbl_deep_extend(
            "keep",
            module,
            require("neorg.modules." .. module.name .. "." .. filename)(module)
        )
        return vim.tbl_deep_extend(
            "force",
            module,
            require("neorg.modules." .. module.name .. "." .. filename)(new_module)
        )
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
}

return neorg.utils
