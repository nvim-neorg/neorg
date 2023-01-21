local docgen = {}

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

---@alias TopComment { file: string, title: string, summary: string, markdown: string[], internal: boolean }

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
    local query = vim.treesitter.parse_query("lua", [[
        (assignment_statement
          (variable_list) @_name
          (#eq? @_name "module.config.public")) @declaration
    ]])

    local _, declaration_node = query:iter_captures(root, buffer)()

    return declaration_node and declaration_node:named_child(1):named_child(0) or nil
end

--- TODO
---@param start_node userdata #Node
---@param callback function
docgen.map_config = function(buffer, start_node, callback)
    local comments = {}

    local query = vim.treesitter.parse_query("lua", [[
        ((comment)+ @comment
        .
        (field) @field)
    ]])

    for capture_id, node in query:iter_captures(start_node, buffer) do
        local capture = query.captures[capture_id]

        if capture == "comment" then
            table.insert(comments, ts.get_node_text(node, buffer))
        elseif capture == "field" and node:parent():id() == start_node:id() then
            local name = ts.get_node_text(node:named_child(0), buffer)
            local value = node:named_child(1)

            if value:type() == "table_constructor" then
                callback({
                    node = node,
                    name = name,
                    value = value,
                }, comments)

                docgen.map_config(buffer, node, callback)
            else
                callback({
                    node = node,
                    name = name,
                    value = value,
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

---@alias Modules { [string]: { top_comment_data: TopComment, buffer: number, parsed: table } }

docgen.generators = {
    --- Generates the Home.md file
    ---@param modules Modules #A table of modules
    homepage = function(modules)
        local core_defaults = modules["core.defaults"]
        assert(core_defaults, "core.defaults module not loaded!")

        local function list_modules_with_predicate(predicate)
            return function()
                local res = {}

                for mod, data in pairs(modules) do
                    if predicate(data) then
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
                    .. " module:" }
            end,
            "",
            list_modules_with_predicate(function(data) return vim.tbl_contains(core_defaults.parsed.config.public.enable, data.parsed.name) and not data.top_comment_data.internal end),
            "",
            "# Other Modules",
            "",
            "Some modules are not included by default as they require some manual configuration or are merely extra bells and whistles",
            "and are not critical to editing `.norg` files. Below is a list of all modules that are not required by default:",
            "",
            list_modules_with_predicate(function(data)
                return not data.parsed.extension
                and not vim.tbl_contains(core_defaults.parsed.config.public.enable, data.parsed.name)
                and not data.top_comment_data.internal
            end),
            "",
            "# Developer modules",
            "",
            "These are modules that are only meant for developers. They are generally required in other modules:",
            "",
            list_modules_with_predicate(function(data)
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

return docgen
