local docgen = {}

-- Create the directory if it does not exist
docgen.output_dir = "wiki"
pcall(vim.fn.mkdir, docgen.output_dir)

local scan = require("plenary.scandir")

require("neorg").setup({
    load = {
        ["core.defaults"] = {},
        ["core.gtd.base"] = {},
        ["core.integrations.treesitter"] = {},
    },
})

-- Start neorg
neorg.org_file_entered(false)

-- Extract treesitter utility functions provided by Neorg and nvim-treesitter.ts_utils
local ts = neorg.modules.get_module("core.integrations.treesitter")
local ts_utils = ts.get_ts_utils()

-- Store all parsed modules in this variable
local modules = {}

--- Get the list of every module.lua file in neorg
--- @return table
docgen.find_modules = function()
    local path = vim.fn.getcwd()
    local neorg_modules = "lua/neorg/modules"

    return scan.scan_dir(path .. "/" .. neorg_modules, { search_pattern = "module.lua$" })
end

--- Get bufnr from a filepath
--- @param path string
--- @return number
docgen.get_buf_from_file = function(path)
    local uri = vim.uri_from_fname(path)
    local buf = vim.uri_to_bufnr(uri)

    return buf
end

--- Get the first comment (at line 0) from a module and get it's content
--- @param path string
--- @return number, table #Returns the buffer and the table of comment
docgen.get_module_top_comment = function(path)
    local buf = docgen.get_buf_from_file(path)
    local node = ts.get_first_node_recursive("comment", { buf = buf, ft = "lua" })

    if not node then
        return
    end

    -- Verify if it's the first line
    local start_row = ts_utils.get_node_range(node)
    if start_row ~= 0 then
        return
    end

    local comment = ts_utils.get_node_text(node, buf)

    -- Stops execution if it's not a multiline comment
    if not comment[1] == "--[[" or not comment[#comment] == "--]]" then
        return
    end

    -- Removes first and last braces
    table.remove(comment, 1)
    table.remove(comment, #comment)

    return buf, comment
end

--- Parses the query from a buffer
--- @param buf number
--- @param query string
--- @return table
docgen.get_module_queries = function(buf, query)
    vim.api.nvim_set_current_buf(buf)

    return vim.treesitter.parse_query("lua", query)
end

--- Get module.config.public TS node from buffer
--- @param buf number
docgen.get_module_configs = function(buf)
    local nodes = ts.get_all_nodes("variable_declaration", { ft = "lua", buf = buf })
    for _, node in pairs(nodes) do
        local _node = ts.get_first_node_recursive("variable_declarator", { ft = "lua", buf = buf, parent = node })
        local text = ts_utils.get_node_text(_node, buf)[1]
        if text == "module.config.public" then
            _node = ts.get_first_node_recursive("table", { ft = "lua", buf = buf, parent = node })
            return _node
        end
    end
end

--- The actual code that generates a md file from a template
--- @param buf number
--- @param path string
--- @param comment table
docgen.generate_md_file = function(buf, path, comment, main_page)
    local module = {}
    if not main_page then
        module = dofile(path)
        neorg.modules.load_module(module.name)
        module = neorg.modules.loaded_modules[module.name].real()

        for _, import in ipairs(module.setup().imports or {}) do
            local import_path = vim.fn.fnamemodify(path, ":p:h") .. "/" .. import .. ".lua"
            local imported_extension = dofile(import_path).real()
            imported_extension.path = import_path
            modules[imported_extension.name] = imported_extension
        end

        modules[module.name] = module
    end

    local structure
    if main_page == "Home" then
        structure = {
            "<div align='center'>",
            "# Welcome to the neorg wiki !",
            "</div>",
            "",
            "# Using Neorg",
            "",
            "At first configuring Neorg might be rather scary. I have to define what modules I want to use in the `require('neorg').setup()` function? I don't even know what the default available values are.",
            "Don't worry, an installation guide is present [here](https://github.com/nvim-neorg/neorg/wiki/Installation), so go ahead and read it!",
            "",
            "# Contributing to Neorg",
            "",
            "Neorg is a very big and powerful tool behind the scenes - way bigger than it may initially seem.",
            "Modules are its core foundation, and building modules is like building lego bricks to form a massive structure!",
            "There's a whole tutorial dedicated to making modules [right here](https://github.com/nvim-neorg/neorg/wiki/Creating-Modules).",
            "There everything you need will be explained - think of it as a walkthrough.",
            "",
            "# Builtin Modules",
            "",
            "Neorg comes with its own builtin modules to make development easier. Below is a list of all currently implemented builtin modules:",
            function()
                local res = {}
                -- P(modules)
                for _module, _config in pairs(modules) do
                    local insert
                    if _config.filename then
                        insert = "- [`"
                            .. _config.name
                            .. "`](https://github.com/nvim-neorg/neorg/wiki/"
                            .. _config.filename
                            .. ")"
                    else
                        insert = "- `" .. _module .. "`"
                    end
                    if _config.summary then
                        insert = insert .. " - " .. _config.summary
                    else
                        insert = insert .. " - undocumented module"
                    end

                    table.insert(res, insert)
                end
                return res
            end,
        }
    elseif main_page == "_Sidebar" then
        structure = {
            "<div align='center'>",
            "",
            "# :star2: Neorg",
            "</div>",
            "",
            "### Setting Up",
            "- [Installation Guide](https://github.com/nvim-neorg/neorg/wiki/Installation)",
            "- [How do I configure modules?](https://github.com/nvim-neorg/neorg/wiki/Configuring-Modules)",
            "- [User Keybinds](https://github.com/nvim-neorg/neorg/wiki/User-Keybinds)",
            "- [User Callbacks](https://github.com/nvim-neorg/neorg/wiki/User-Callbacks)",
            "- [Modifying Neorg Highlights](https://github.com/nvim-neorg/neorg/wiki/Custom-Highlights)",
            "- [Customizing Icons](https://github.com/nvim-neorg/neorg/wiki/Concealing)",
            "### Usage",
            "- [Managing Workspaces](https://github.com/nvim-neorg/neorg/wiki/Workspace-Management)",
            "- [Constructing a Workflow](https://github.com/nvim-neorg/neorg/wiki/Constructing-a-Workflow)",
            "### For the programmer",
            "- [Writing my own module](https://github.com/nvim-neorg/neorg/wiki/Creating-Modules)",
            "- [Hotswapping modules](https://github.com/nvim-neorg/neorg/wiki/Hotswapping-Modules)",
            "- [Difference between module.public and module.config.public](https://github.com/nvim-neorg/neorg/wiki/Public-vs-Public-Config)",
            "- [Metamodules](https://github.com/nvim-neorg/neorg/wiki/Metamodules)",
            "",
            "<details>",
            "<summary>Inbuilt modules:</summary>",
            "",
            function()
                local res = {}
                -- P(modules)
                names = {}
                for n in pairs(modules) do
                    table.insert(names, n)
                end
                table.sort(names)
                for i, name in ipairs(names) do
                    _config = modules[name]
                    local insert = ""
                    if _config.filename then
                        insert = insert
                            .. "- [`"
                            .. _config.name
                            .. "`](https://github.com/nvim-neorg/neorg/wiki/"
                            .. _config.filename
                            .. ")"
                    else
                        insert = insert .. "- `" .. name .. "`"
                    end

                    table.insert(res, insert)
                end
                return res
            end,
            "</details>",
        }
    else
        structure = {
            function()
                return { module.title and "# " .. module.title or ("# The `" .. module.name .. "` Module") }
            end,
            "",
            "## Summary",
            function()
                return { (module.summary or "*no summary provided*") }
            end,
            "",
            "## Overview",
            "<comment>",
            "",
            "## Usage",
            "### How to Apply",
            function()
                local core_defaults = modules["core.defaults"]

                if not core_defaults then
                    return
                end

                if
                    not vim.tbl_isempty(vim.tbl_filter(function(elem)
                        return elem == module.name
                    end, core_defaults.config.public.enable or {}))
                then
                    return {
                        "- This module is already present in the [`core.defaults`](https://github.com/nvim-neorg/neorg/wiki/"
                            .. core_defaults.filename
                            .. ") metamodule.",
                        "  You can load the module with:",
                        "  ```lua",
                        '  ["core.defaults"] = {},',
                        "  ```",
                        "  In your Neorg setup.",
                    }
                end
            end,
            "- To manually load the module, place this code in your Neorg setup:",
            "  ```lua",
            '  ["' .. module.name .. '"] = {',
            "     config = { -- Note that this table is optional and doesn't need to be provided",
            "         -- Configuration here",
            "     }",
            "  }",
            "  ```",
            "  Consult the [configuration](#Configuration) section to see how you can configure `"
                .. module.name
                .. "` to your liking.",
            "",
            "### Configuration",
            function()
                local results = {}
                local configs = docgen.get_module_configs(buf)

                if not configs then
                    table.insert(results, "No configuration provided")
                else
                    local inserted = {}
                    local current_key = {}
                    for child, _ in configs:iter_children() do
                        if child:type() == "comment" then
                            local insert = ts_utils.get_node_text(child, buf)
                            current_key = current_key and vim.list_extend(current_key, insert)
                        elseif child:type() == "field" and not vim.tbl_isempty(current_key) then
                            local name = ts_utils.get_node_text(child:named_child(0), buf)[1]
                            local value = ts_utils.get_node_text(child:named_child(1), buf)

                            if child:named_child(1):type() == "table" then
                                local count
                                -- Remove whitespaces
                                value[#value], count = string.gsub(value[#value], "%s*", "")
                                for i, _value in pairs(value) do
                                    local pattern = string.rep("%s", count)
                                    value[i] = string.gsub(_value, pattern, "")
                                end
                            end

                            table.insert(inserted, { comment = current_key, value = value, name = name })
                            current_key = {}
                        else
                            current_key = {}
                        end
                    end

                    if vim.tbl_isempty(inserted) then
                        table.insert(results, "No public configuration")
                    end
                    for _, insert in pairs(inserted) do
                        table.insert(results, "- `" .. insert.name .. "`")
                        table.insert(results, "")
                        for _, _value in pairs(insert.comment) do
                            table.insert(results, string.sub(_value, 4))
                            table.insert(results, "")
                        end
                        table.insert(results, "```lua")
                        for _, _value in pairs(insert.value) do
                            table.insert(results, _value)
                        end
                        table.insert(results, "```")
                    end
                end

                return results
            end,
            "## Developer Usage",
            "### Public API",
            "This segment will detail all of the functions `"
                .. module.name
                .. "` exposes. All of these functions reside in the `public` table.",
            "",
            function()
                local api = neorg.modules.get_module(module.name)
                local results = {}

                if not vim.tbl_isempty(api) then
                    for function_name, item in pairs(api) do
                        if type(item) == "function" then
                            table.insert(results, "- `" .. function_name .. "`")
                        end
                    end
                    if #results == 0 then
                        table.insert(results, "No public functions exposed.")
                    end

                    table.insert(results, "")
                end

                return results
            end,
            "### Examples",
            {
                query = [[
                (variable_declaration
                    (variable_declarator
                        (field_expression) @_field
                        (#eq? @_field "module.examples")
                    )
                ) @declaration
            ]],

                callback = function(main_query)
                    if vim.tbl_isempty(module.examples) then
                        return { "None Provided" }
                    end

                    local tree = vim.treesitter.get_parser(buf, "lua"):parse()[1]
                    local result = {}
                    local index = 0

                    for _, variable_declaration in main_query:iter_captures(tree:root(), buf) do
                        if variable_declaration:type() == "variable_declaration" then
                            local query = vim.treesitter.parse_query(
                                "lua",
                                [[
                            (table
                                (field
                                    [
                                        (identifier)
                                        (string)
                                    ] @identifier
                                    (function_definition
                                        (parameters)
                                    )
                                )
                            )
                        ]]
                            )

                            for id, node in query:iter_captures(variable_declaration, buf) do
                                local capture = query.captures[id]

                                if capture == "identifier" then
                                    index = index + 1
                                    local identifier_text = ts.get_node_text(node)
                                    identifier_text = identifier_text:gsub("[\"'](.+)[\"']", "%1") or identifier_text

                                    result[index] = {
                                        "#### " .. identifier_text,
                                        "```lua",
                                    }

                                    local start_node = node:next_named_sibling()

                                    if not start_node then
                                        table.insert(result[index], "-- empty code block")
                                    end

                                    local text = ts_utils.get_node_text(start_node)

                                    -- Remove the function() and "end" keywords
                                    table.remove(text, 1)
                                    table.remove(text)

                                    local start = vim.api.nvim_strwidth(text[1]:match("^%s*")) + 1

                                    for i = 1, #text do
                                        text[i] = text[i]:sub(start)
                                    end

                                    vim.list_extend(result[index], text)

                                    table.insert(result[index], "```")
                                    table.insert(result[index], "")
                                end
                            end
                        end
                    end

                    return vim.tbl_flatten(result)
                end,
            },
            "",
            "## Extra Info",
            "### Version",
            "This module supports at least version **" .. module.public.version .. "**.",
            "The current Neorg version is **" .. neorg.configuration.version .. "**.",
            "",
            "### Imports",
            function()
                local imports = module.setup().imports

                if not imports or vim.tbl_isempty(imports) then
                    return { "This module does not import any other files." }
                end

                local ret = {}

                for _, import in ipairs(imports) do
                    local import_module = modules[module.name .. "." .. import]

                    if not import_module then
                        return
                    end

                    local trimmed = import_module.path:sub(import_module.path:find("/lua/") + 1, -1)

                    table.insert(
                        ret,
                        "- [`"
                            .. module.name
                            .. "."
                            .. import
                            .. "`](https://github.com/nvim-neorg/neorg/tree/unstable/"
                            .. trimmed
                            .. ")"
                    )
                end

                return ret
            end,
            "",
            "### Requires",
            function()
                local required = module.setup().requires

                if not required or vim.tbl_isempty(required) or not modules[required[1]] then
                    return { "This module does not require any other modules to operate." }
                end

                local ret = {}

                for _, name in ipairs(required) do
                    if modules[name] and modules[name].filename then
                        modules[name].required_by = modules[name].required_by or {}
                        table.insert(modules[name].required_by, module.name)

                        ret[#ret + 1] = "- [`"
                            .. name
                            .. "`](https://github.com/nvim-neorg/neorg/wiki/"
                            .. modules[name].filename
                            .. ") - "
                            .. (modules[name].summary or "no description")
                    else
                        ret[#ret + 1] = "- `" .. name .. "` - undocumented module"
                    end
                end

                return ret
            end,
            "",
            "### Required by",
            function()
                if not module.required_by or vim.tbl_isempty(module.required_by) then
                    return { "This module isn't required by any other module." }
                end

                local ret = {}

                for _, name in ipairs(module.required_by) do
                    if modules[name] and modules[name].filename then
                        ret[#ret + 1] = "- [`"
                            .. name
                            .. "`](https://github.com/nvim-neorg/neorg/wiki/"
                            .. modules[name].filename
                            .. ") - "
                            .. (modules[name].summary or "no description")
                    else
                        ret[#ret + 1] = "- `" .. name .. "` - undocumented module"
                    end
                end

                return ret
            end,
        }
    end

    if (not comment or #comment == 0) and not main_page then
        return
    end

    local oldkey
    local arguments = {}

    if not main_page then
        for i, line in ipairs(comment) do
            if line:match("^%s*---$") then
                comment = vim.list_slice(comment, i + 1)
                break
            end

            local key, value = line:match("^%s*([%w%s]+)%:%s+(.+)$")

            if key and value then
                key = key:lower():gsub("%s", "_")
                arguments[key] = value
                oldkey = key
            elseif not line:match("^%s*$") and oldkey then
                arguments[oldkey] = arguments[oldkey] .. " " .. vim.trim(line)
            end
        end
    end

    if not arguments.file and not main_page then
        return
    end

    -- Populate the module with some extra info
    module.filename = arguments.file or main_page
    module.summary = arguments.summary
    module.title = arguments.title

    -- Construct the desired filename
    local output_filename = module.filename .. ".md"

    local output = {}

    -- Generate structure
    for _, item in ipairs(structure) do
        if type(item) == "string" then
            if item == "<comment>" then
                vim.list_extend(output, comment)
            else
                table.insert(output, item)
            end
        elseif type(item) == "table" then
            local query = docgen.get_module_queries(buf, item.query)

            if query then
                local ret = item.callback(query)

                for _, str in ipairs(ret) do
                    table.insert(output, str)
                end
            end
        elseif type(item) == "function" then
            vim.list_extend(output, item() or {})
        end
    end

    local output_buffer = vim.api.nvim_create_buf(false, false)
    local output_path = vim.fn.getcwd() .. "/" .. docgen.output_dir .. "/" .. output_filename
    vim.api.nvim_buf_set_name(output_buffer, output_path)
    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, output)
    vim.api.nvim_buf_call(output_buffer, function()
        vim.cmd("write!")
    end)
    vim.api.nvim_buf_delete(output_buffer, { force = true })
end

docgen.generate_main_file = function() end

docgen.generate_sidebar_file = function() end

local files = docgen.find_modules()

for _ = 1, 2 do
    for _, file in ipairs(files) do
        local buf, comment = docgen.get_module_top_comment(file)

        if comment then
            docgen.generate_md_file(buf, file, comment)
        end
    end
end

docgen.generate_md_file(nil, nil, nil, "Home")
docgen.generate_md_file(nil, nil, nil, "_Sidebar")

return docgen
