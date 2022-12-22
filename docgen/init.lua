local docgen = require("docgen")
local modules = {}

for _, file in ipairs(docgen.aggregate_module_files()) do
    local buffer = docgen.open_file(file)

    local top_comment = docgen.get_module_top_comment(buffer)

    if not top_comment then
        goto continue
    end

    top_comment = docgen.parse_top_comment(top_comment)

    ::continue::
end
