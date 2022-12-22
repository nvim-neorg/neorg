local docgen = {}

-- Create the directory if it does not exist
docgen.output_dir = "wiki"
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
    local start_row = ts_utils.get_node_range(node)
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

---@alias TopComment { file: string, title: string, summary: string, markdown: string[] }

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
    elseif tc.summary:sub(tc.summary:len()) ~= "." then
        return "summary does not end with a full stop."
    elseif tc.title:find("neorg") then
        return "`neorg` written with lowercase letter. Use uppercase instead."
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

return docgen
