local docgen = require("docgen")
local fileio = require("fileio")
---@type Modules
local modules = {
    --[[
    [name] = {
        top_comment_data...
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

    local top_comment_data = docgen.check_top_comment_integrity(docgen.parse_top_comment(top_comment))

    if type(top_comment_data) == "string" then
        log.error("Error when parsing module '" .. file .. "': " .. top_comment_data)
        goto continue
    end

    -- Source the module file to retrieve some basic information like its name
    local ok, parsed_module = pcall(dofile, fullpath)

    if not ok then
        log.error("Error when sourcing module '" .. file .. ": " .. parsed_module)
        return
    end

    -- Make Neorg load the module, which also evaluates dependencies and imports
    neorg.modules.load_module(parsed_module.name)

    -- Retrieve the module from the `loaded_modules` table.
    parsed_module = neorg.modules.loaded_modules[parsed_module.name].real()

    modules[parsed_module.name] = {
        top_comment_data = top_comment_data,
        buffer = buffer,
        parsed = parsed_module,
    }

    ::continue::
end

local homepage_content = docgen.generators.homepage(modules)
fileio.write_to_wiki("Home", homepage_content)

for module_name, module in pairs(modules) do
    local buffer = module.buffer

    local root = vim.treesitter.get_parser(buffer, "lua"):parse()[1]:root()
    local config_node = docgen.get_module_config_node(buffer, root)

    if config_node then
        docgen.map_config(buffer, config_node, function(child, comment)

        end)
    end
end
