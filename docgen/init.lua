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
        vim.notify("no top comment found for module " .. file)
        goto continue
    end

    local top_comment_data = docgen.check_top_comment_integrity(docgen.parse_top_comment(top_comment))

    if type(top_comment_data) == "string" then
        vim.notify("Error when parsing module '" .. file .. "': " .. top_comment_data)
        goto continue
    end

    -- Source the module file to retrieve some basic information like its name
    local ok, parsed_module = pcall(dofile, fullpath)

    if not ok then
        vim.notify("Error when sourcing module '" .. file .. ": " .. parsed_module)
        goto continue
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

fileio.write_to_wiki("Home", docgen.generators.homepage(modules))
fileio.write_to_wiki("_Sidebar", docgen.generators.sidebar(modules))

-- Loop through all modules and generate their respective wiki files
for module_name, module in pairs(modules) do
    local buffer = module.buffer

    -- Query the root node and try to find a `module.config.public` table
    local root = vim.treesitter.get_parser(buffer, "lua"):parse()[1]:root()
    local config_node = docgen.get_module_config_node(buffer, root)

    -- A table of markdown lines corresponding to every configuration option
    local configuration_options = {}

    if config_node then
        docgen.map_config(buffer, config_node, function(data, comments)
            for i, comment in ipairs(comments) do
                comments[i] = docgen.lookup_modules(modules, comment:gsub("^%s*%-%-+%s*", ""))
            end

            do
                local error = docgen.check_comment_integrity(table.concat(comments, "\n"))

                if type(error) == "string" then
                    -- Get the exact location of the error with data.node and the file it was contained in
                    local start_row, start_col = data.node:start()

                    vim.notify(
                        ("Error when parsing annotation in module '%s' on line (%d, %d): %s"):format(
                            module_name,
                            start_row,
                            start_col,
                            error
                        )
                    )
                    return
                end
            end

            -- TODO: Create a whitelist for e.g. binary operations, function()s, function calls etc
            -- TODO: Allow modules to attach gifs about what they do and how they work

            if data.value then
                log.warn(docgen.to_lua_object(module.parsed, buffer, data.value, module_name))
            end
        end)
    end

    -- Perform module lookups in the module's top comment markdown data.
    -- This cannot be done earlier because then there would be no guarantee
    -- that all the modules have been properly indexed and parsed.
    for i, line in ipairs(module.top_comment_data.markdown) do
        module.top_comment_data.markdown[i] = docgen.lookup_modules(modules, line)
    end
end
