local docgen = require("docgen")
local modules = {}

for _, file in ipairs(docgen.aggregate_module_files()) do
    local buffer = docgen.open_file(vim.fn.fnamemodify(file, ":p"))

    local top_comment = docgen.get_module_top_comment(buffer)

    if not top_comment then
        goto continue
    end

    local docgen_data = docgen.check_top_comment_integrity(docgen.parse_top_comment(top_comment))

    if type(docgen_data) == "string" then
        log.error("Error when parsing module '" .. file .. "': " .. docgen_data)
    end

    ::continue::
end
