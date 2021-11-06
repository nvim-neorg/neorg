local docgen = {}

docgen.output_dir = "wiki"

pcall(vim.fn.mkdir, docgen.output_dir)

local scan = require("plenary.scandir")

require("neorg").setup({
    load = {
        ["core.integrations.treesitter"] = {},
    },
})

-- Start neorg
neorg.org_file_entered(false)
local ts = neorg.modules.get_module("core.integrations.treesitter")
local ts_utils = ts.get_ts_utils()

docgen.find_modules = function()
    local path = vim.fn.getcwd()
    local neorg_modules = "lua/neorg/modules"

    return scan.scan_dir(path .. "/" .. neorg_modules, { search_pattern = "module.lua$" })
end

docgen.get_buf_from_file = function(path)
    local uri = vim.uri_from_fname(path)
    local buf = vim.uri_to_bufnr(uri)

    return buf
end

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

    return comment
end

docgen.generate_md_file = function(comment)
    if not comment or #comment == 0 then
        return
    end

    comment[1] = string.gsub(comment[1], "^%s*(.-)%s*$", "%1")

    -- Checks if we want to generate as a file
    if not vim.startswith(comment[1], "File: ") then
        return
    end

    -- Only keeps the desired file name
    local output_filename = string.gsub(comment[1], "^File: ", "") .. ".md"
    table.remove(comment, 1)

    local buf = vim.api.nvim_create_buf(false, false)
    local path = vim.fn.getcwd() .. "/" .. docgen.output_dir .. "/" .. output_filename
    vim.api.nvim_buf_set_name(buf, path)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, comment)
    vim.api.nvim_buf_call(buf, function ()
        vim.cmd("write!")
    end)
end

local files = docgen.find_modules()
for _, file in ipairs(files) do
    local comment = docgen.get_module_top_comment(file)

    if comment then
        docgen.generate_md_file(comment)
    end
end

return docgen
