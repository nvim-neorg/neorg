local docgen = require("docgen")
local modules = {
    --[[
    [name] = {
        docgen_data...
        buffer = id,
        parsed = `ret value from sourcing the file`,
    }
    --]]
}

for _, file in ipairs(docgen.aggregate_module_files()) do
    local fullpath = vim.fn.fnamemodify(file, ":p")

    local buffer = docgen.open_file(fullpath)

    local top_comment = docgen.get_module_top_comment(buffer)

    if not top_comment then
        goto continue
    end

    local docgen_data = docgen.check_top_comment_integrity(docgen.parse_top_comment(top_comment))

    if type(docgen_data) == "string" then
        log.error("Error when parsing module '" .. file .. "': " .. docgen_data)
        goto continue
    end

    local ok, parsed_module = pcall(dofile, fullpath)

    if not ok then
        log.error("Error when sourcing module '" .. file .. ": " .. parsed_module)
        return
    end

    modules[parsed_module.name] = {
        data = docgen_data,
        buffer = buffer,
        parsed = parsed_module,
    }

    ::continue::
end

for module_name, module in pairs(modules) do
    local buffer = module.buffer

    local root = vim.treesitter.get_parser(buffer, "lua"):parse()[1]:root()
    local config_node = docgen.get_module_config_node(buffer, root)

    if config_node then
        docgen.map_config(buffer, config_node, function(child, comment)
        end)
    end
end
