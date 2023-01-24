--[[
--    HELPER FUNCTIONS FOR NEORG
--    This file contains some simple helper functions to improve QOL
--]]

local utils = {

    --- An OS agnostic way of querying the current user
    get_username = function()
        local current_os = neorg.configuration.os_info

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


return utils
