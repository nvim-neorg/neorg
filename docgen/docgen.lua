local docgen = {}

require("neorg.external.helpers")

-- Create the directory if it does not exist
docgen.output_dir = "../wiki"
pcall(vim.fn.mkdir, docgen.output_dir)

require("neorg").setup({
    load = {
        ["core.defaults"] = {},
        ["core.integrations.treesitter"] = {
            config = {
                configure_parsers = false,
            },
        },
    },
})

-- Start neorg
neorg.org_file_entered(false)

-- Extract treesitter utility functions provided by Neorg and nvim-treesitter.ts_utils
local ts = neorg.modules.get_module("core.integrations.treesitter")
assert(ts, "treesitter not available")

local ts_utils = ts.get_ts_utils()

--- Aggregates all the available modules.
---@return table #A list of paths to every module's `module.lua` file
docgen.aggregate_module_files = function()
    return vim.fs.find("module.lua", {
        path = "..",
        type = "file",
        limit = math.huge,
    })
end

--- Opens a file from a given path in a new buffer
---@param path string #The path of the file to open
---@return number #The buffer ID of the opened file
docgen.open_file = function(path)
    local uri = vim.uri_from_fname(path)
    local buf = vim.uri_to_bufnr(uri)

    return buf
end

--- Get the first comment (at line 0) from a module and get it's content
--- @param buf number #The buffer number to read from
--- @return table? #A table of lines
docgen.get_module_top_comment = function(buf)
    local node = ts.get_first_node_recursive("comment", { buf = buf, ft = "lua" })

    if not node then
        return
    end

    -- Verify if it's the first line
    local start_row = node:range()
    if start_row ~= 0 then
        return
    end

    local comment = vim.split(ts.get_node_text(node, buf), "\n")

    -- Stops execution if it's not a multiline comment
    if not comment[1] == "--[[" or not comment[#comment] == "--]]" then
        return
    end

    -- Removes first and last braces
    table.remove(comment, 1)
    table.remove(comment, #comment)

    return comment
end

---@alias TopComment { file: string, title: string, summary: string, description: string, embed: string, markdown: string[], internal: boolean }

--- Parses the top comment
---@param comment string[] #The comment
---@return TopComment #The parsed comment
docgen.parse_top_comment = function(comment)
    ---@type TopComment
    local result = {
        -- file = "",
        -- title = "",
        -- summary = "",
        markdown = {},
    }
    local can_have_options = true

    for _, line in ipairs(comment) do
        if line:match("^%s*%-%-%-%s*$") then
            can_have_options = false
        else
            local option_name, value = line:match("^%s*(%w+):%s*(.+)")

            if vim.tbl_contains({ "true", "false" }, value) then
                value = (value == "true")
            end

            if option_name and can_have_options then
                result[option_name:lower()] = value
            else
                table.insert(result.markdown, line)
            end
        end
    end

    return result
end

--- TODO
---@param top_comment TopComment #The comment to check for errors
---@return string|TopComment #An error string or the comment itself
docgen.check_top_comment_integrity = function(top_comment)
    local tc = vim.tbl_deep_extend("keep", top_comment, {
        title = "",
        summary = "",
        markdown = {},
    })

    if not tc.file then
        return "no `File:` field provided."
    elseif tc.summary:sub(1, 1):upper() ~= tc.summary:sub(1, 1) then
        return "summary does not begin with a capital letter."
    elseif tc.summary:sub(tc.summary:len()) ~= "." then
        return "summary does not end with a full stop."
    elseif tc.title:find("neorg") then
        return "`neorg` written with lowercase letter. Use uppercase instead."
        -- elseif vim.tbl_isempty(tc.markdown) then
        --     return "no overview provided."
    end

    return top_comment
end

--- TODO
---@param buffer number #Buffer ID
---@param root userdata #The root node
---@return userdata? #Root node
docgen.get_module_config_node = function(buffer, root)
    local query = vim.treesitter.parse_query(
        "lua",
        [[
        (assignment_statement
          (variable_list) @_name
          (#eq? @_name "module.config.public")) @declaration
    ]]
    )

    local _, declaration_node = query:iter_captures(root, buffer)()

    return declaration_node and declaration_node:named_child(1):named_child(0) or nil
end

---@param start_node userdata #Node
---@param callback function
---@param parents string[]? #Used internally to track nesting levels
docgen.map_config = function(buffer, start_node, callback, parents)
    parents = parents or {}

    local comments = {}

    for node in start_node:iter_children() do
        if node:type() == "comment" then
            table.insert(comments, ts.get_node_text(node, buffer))
        elseif node:type() == "field" then
            local name_node = node:field("name")[1]
            local name = name_node and ts.get_node_text(name_node, buffer) or nil
            local value = node:field("value")[1]

            if value:type() == "table_constructor" then
                callback({
                    node = node,
                    name = name,
                    value = value,
                    parents = parents,
                }, comments)

                if name then
                    local copy = vim.deepcopy(parents)
                    table.insert(copy, name)
                    docgen.map_config(buffer, value, callback, copy)
                end
            else
                callback({
                    node = node,
                    name = name,
                    value = value,
                    parents = parents,
                }, comments)
            end

            comments = {}
        else
            comments = {}
        end
    end
end

--- Goes through a table and evaluates all functions in that table, merging the
--  return values back into the original table.
---@param tbl table #Input table
---@return table #The new table
docgen.evaluate_functions = function(tbl)
    local new = {}

    neorg.lib.map(tbl, function(_, value)
        if type(value) == "function" then
            vim.list_extend(new, value())
        else
            table.insert(new, value)
        end
    end)

    return new
end

---@alias Module { top_comment_data: TopComment, buffer: number, parsed: table }
---@alias Modules { [string]: Module }

local function list_modules_with_predicate(modules, predicate)
    return function()
        local res = {}

        for mod, data in pairs(modules) do
            if predicate and predicate(data) then
                local insert

                if data.top_comment_data.file then
                    insert = "- [`"
                        .. data.parsed.name
                        .. "`](https://github.com/nvim-neorg/neorg/wiki/"
                        .. data.top_comment_data.file
                        .. ")"
                else
                    insert = "- `" .. mod .. "`"
                end

                if data.top_comment_data.summary then
                    insert = insert .. " - " .. data.top_comment_data.summary
                else
                    insert = insert .. " - undocumented module"
                end

                table.insert(res, insert)
            end
        end

        return res
    end
end

docgen.generators = {
    --- Generates the Home.md file
    ---@param modules Modules #A table of modules
    homepage = function(modules)
        local core_defaults = modules["core.defaults"]
        assert(core_defaults, "core.defaults module not loaded!")

        local structure = {
            '<div align="center">',
            "",
            "# Welcome to the Neorg wiki!",
            "Want to know how to properly use Neorg? Your answers are contained here.",
            "",
            "</div>",
            "",
            "# Using Neorg",
            "",
            "At first configuring Neorg might be rather scary. I have to define what modules I want to use in the `require('neorg').setup()` function?",
            "I don't even know what the default available values are!",
            "Don't worry, an installation guide is present [here](https://github.com/nvim-neorg/neorg#-installation), so go ahead and read it!",
            "",
            "# Contributing to Neorg",
            "",
            "Neorg is a very big and powerful tool behind the scenes - way bigger than it may initially seem.",
            "Modules are its core foundation, and building modules is like building lego bricks to form a massive structure!",
            "There's a whole tutorial dedicated to making modules [right here](https://github.com/nvim-neorg/neorg/wiki/Creating-Modules).",
            "There everything you need will be explained - think of it as a walkthrough.",
            "# Module naming convention",
            "Neorg provides default modules, and users can extend Neorg by creating community modules.",
            "We agreed on a module naming convention, and it should be used as is.",
            "This convention should help users know at a glance what function the module serves in the grand scheme of things.",
            "- Core modules: `core.*`",
            "- Integrations with 3rd party software that are emdebbed in neorg: `core.integrations.*`",
            "- External modules: `external.*`",
            "- Integrations with 3rd party software that aren't emdebbed in neorg: `external.integrations.*`",
            "",
            "# Default Modules",
            "",
            function()
                local link = "[`core.defaults`](https://github.com/nvim-neorg/neorg/wiki/"
                    .. core_defaults.top_comment_data.file
                    .. ")"
                return {
                    "Neorg comes with some default modules that will be automatically loaded if you require the "
                        .. link
                        .. " module:",
                }
            end,
            "",
            list_modules_with_predicate(modules, function(data)
                return vim.tbl_contains(core_defaults.parsed.config.public.enable, data.parsed.name)
                    and not data.top_comment_data.internal
            end),
            "",
            "# Other Modules",
            "",
            "Some modules are not included by default as they require some manual configuration or are merely extra bells and whistles",
            "and are not critical to editing `.norg` files. Below is a list of all modules that are not required by default:",
            "",
            list_modules_with_predicate(modules, function(data)
                return not data.parsed.extension
                    and not vim.tbl_contains(core_defaults.parsed.config.public.enable, data.parsed.name)
                    and not data.top_comment_data.internal
            end),
            "",
            "# Developer modules",
            "",
            "These are modules that are only meant for developers. They are generally required in other modules:",
            "",
            list_modules_with_predicate(modules, function(data)
                return not data.parsed.extension
                    and not vim.tbl_contains(core_defaults.parsed.config.public.enable, data.parsed.name)
                    and data.top_comment_data.internal
            end),
        }

        return docgen.evaluate_functions(structure)
    end,

    --- Generates the _Sidebar.md file
    ---@param modules Modules #A table of modules
    sidebar = function(modules)
        local structure = {
            "<div align='center'>",
            "",
            "# :star2: Neorg",
            "</div>",
            "",
            "### Setting Up",
            "- [How do I configure modules?](https://github.com/nvim-neorg/neorg/wiki/Configuring-Modules)",
            "- [User Keybinds](https://github.com/nvim-neorg/neorg/wiki/User-Keybinds)",
            "- [User Callbacks](https://github.com/nvim-neorg/neorg/wiki/User-Callbacks)",
            "- [Customizing Icons](https://github.com/nvim-neorg/neorg/wiki/Concealer)",
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
                local names = {}

                for n, data in pairs(modules) do
                    if data.parsed.extension ~= true then
                        table.insert(names, n)
                    end
                end

                table.sort(names)

                for _, name in ipairs(names) do
                    local data = modules[name]
                    if not data.parsed.internal then
                        local insert = ""
                        if data.top_comment_data.file then
                            insert = insert
                                .. "- [`"
                                .. data.parsed.name
                                .. "`](https://github.com/nvim-neorg/neorg/wiki/"
                                .. data.top_comment_data.file
                                .. ")"
                        else
                            insert = insert .. "- `" .. name .. "`"
                        end

                        table.insert(res, insert)
                    end
                end

                return res
            end,
            "",
            "</details>",
        }

        return docgen.evaluate_functions(structure)
    end,

    --- Generates the page for any Neorg module
    ---@param modules Modules #The list of currently loaded modules
    ---@param module Module #The module we want to generate the page for
    ---@param configuration string[] #An array of markdown strings detailing the configuration options for the module
    ---@return string[] #A table of markdown strings representing the page
    module = function(modules, module, configuration)
        local structure = {
            '<div align="center">',
            "",
            "# `" .. module.parsed.name .. "`",
            "",
            "### " .. (module.top_comment_data.title or ""),
            "",
            module.top_comment_data.description or "",
            "",
            module.top_comment_data.embed and ("![module-showcase](" .. module.top_comment_data.embed .. ")") or "",
            "",
            "</div>",
            "",
            function()
                if module.top_comment_data.markdown and not vim.tbl_isempty(module.top_comment_data.markdown) then
                    return vim.list_extend({
                        "# Overview",
                        "",
                    }, module.top_comment_data.markdown)
                end

                return {}
            end,
            "",
            "# Configuration",
            "",
            function()
                if vim.tbl_isempty(configuration) then
                    return {
                        "This module provides no configuration options!",
                    }
                else
                    return configuration
                end
            end,
            "",
            function()
                local required_modules = module.parsed.setup().requires or {}

                if vim.tbl_isempty(required_modules) then
                    return {}
                end

                local module_list = {}

                for _, module_name in ipairs(required_modules) do
                    module_list[module_name] = modules[module_name]
                end

                return docgen.evaluate_functions({
                    "# Required Modules",
                    "",
                    list_modules_with_predicate(module_list, function()
                        return true
                    end),
                })
            end,
            "",
            function()
                local required_by = {}

                for mod, data in pairs(modules) do
                    local required_modules = data.parsed.setup().requires or {}

                    if vim.tbl_contains(required_modules, module.parsed.name) then
                        required_by[mod] = data
                    end
                end

                if vim.tbl_isempty(required_by) then
                    return {}
                end

                return docgen.evaluate_functions({
                    "# Required By",
                    "",
                    list_modules_with_predicate(required_by, function()
                        return true
                    end)
                })
            end,
        }

        return docgen.evaluate_functions(structure)
    end,
}

--- Check the integrity of the description comments found in configuration blocks
---@param comment string #The comment to check the integrity of
---@return nil|string #`nil` for success, `string` if there was an error
docgen.check_comment_integrity = function(comment)
    if comment:match("^%s*%-%-+%s*") then
        return "found leading `--` comment text."
    elseif comment:sub(1, 1):upper() ~= comment:sub(1, 1) then
        return "comment does not begin with a capital letter."
    elseif comment:find(" neorg ") then
        return "`neorg` written with lowercase letter. Use uppercase instead."
    end
end

--- Replaces all instances of a module reference (e.g. `@core.norg.concealer`) with a link in the wiki
---@param modules Modules #The list of loaded modules
---@param str string #The string to perform the lookup in
---@return string #The original `str` parameter with all `@` references replaced with links
docgen.lookup_modules = function(modules, str)
    return (
        str:gsub("@([%-%.%w]+)", function(target_module_name)
            if not modules[target_module_name] then
                return table.concat({ "@", target_module_name })
            else
                return table.concat({
                    "https://github.com/nvim-neorg/neorg/wiki/",
                    modules[target_module_name].top_comment_data.file,
                })
            end
        end)
    )
end

--- Renders a treesitter node to a lua object
---@param node userdata #The node to render
---@param chunkname string? #The custom name to give to the chunk
---@return any #The converted object
docgen.to_lua_object = function(module, buffer, node, chunkname)
    local loaded = loadstring(table.concat({ "return ", ts.get_node_text(node, buffer) }), chunkname)

    if loaded then
        return setfenv(loaded, vim.tbl_extend("force", getfenv(0), { module = module }))()
    end
end

---@alias ConfigOptionData { node: userdata, name: string, value: userdata, parents: string[] }

--- Converts a lua object to a html node in the resulting HTML document
docgen.render = function(configuration_option, indent)
    indent = indent or 0

    local self = configuration_option.self

    local basis = {
        "* <details" .. (indent == 0 and " open>" or ">"),
        "",
        ((self.data.name or ""):match("^%s*$") and "<summary>List item" or table.concat({
            "<summary><code>",
            self.data.name,
            "</code>",
        })) .. " (" .. type(self.object) .. ")</summary>",
        "",
    }

    if not vim.tbl_isempty(self.comments) then
        vim.list_extend(basis, {
            "<h6>",
            "",
        })

        vim.list_extend(basis, self.comments)
        vim.list_extend(basis, {
            "</h6>",
            "",
        })
    else
        vim.list_extend(basis, {
            "<br>",
            "",
        })
    end

    vim.list_extend(basis, docgen.htmlify(configuration_option, indent))
    vim.list_extend(basis, {
        "",
        "</details>",
    })

    for i, str in ipairs(basis) do
        basis[i] = string.rep(" ", indent + (i > 1 and 2 or 0)) .. str
    end

    return basis
end

docgen.htmlify = function(configuration_option, indent)
    indent = indent or 0

    local self = configuration_option.self

    local result = {}
    local code_block = true

    neorg.lib.match(self.data.value:type())({
        string = function()
            table.insert(result, table.concat({ '"', self.object, '"' }))
        end,
        table_constructor = function()
            table.insert(result, "")

            local unrolled = neorg.lib.unroll(self.object)

            table.sort(unrolled, function(x, y)
                return x[1] < y[1]
            end)

            for _, data in ipairs(unrolled) do
                local name_or_index = data[1]

                local subitem = configuration_option[name_or_index]
                    or (
                        type(name_or_index) == "number"
                            and configuration_option._inline_elements
                            and configuration_option._inline_elements[name_or_index]
                        or nil
                    )

                if subitem then
                    vim.list_extend(result, docgen.render(subitem, indent + 1))
                end
            end

            table.insert(result, "")

            code_block = false
        end,
        function_definition = function()
            local text = ts.get_node_text(self.data.value, self.buffer):match("^function%s*(%b())")

            if not text then
                log.error(string.format("Unable to parse function, perhaps some wrong formatting?"))
                table.insert(result, "<error: incorrect formatting>")
                return
            end

            table.insert(result, "function" .. text)
        end,
        _ = function()
            table.insert(result, ts.get_node_text(self.data.value, self.buffer))
        end,
    })

    if code_block then
        table.insert(result, 1, "```lua")
        table.insert(result, "```")
    end

    return result
end

return docgen
