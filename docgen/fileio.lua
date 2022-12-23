---@author vhyrro
---@license GPLv3

local io = {}

io.write_to_wiki = function(filename, content)
    vim.fn.writefile(content, "../wiki/" .. filename .. ".md")
end

return io
