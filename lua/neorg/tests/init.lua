--[[
This file contains a variety of utility functions for writing Neorg tests.

The functions used here should be generalized and moved out into a separate rock on luarocks.org in due time.

Neorg sets up `busted` using `neolua` (a wrapper around neovim) as its test interpreter. This allows access to all
Neovim-related APIs natively. The entire process occurs in the flake.nix file.
--]]

local tests = {}

--- Sets up Neorg with a given module.
---@param module_name string The name of the module to load.
---@param configuration table? The configuration for the module.
---@return table #The main Neorg table with the setup() function called.
function tests.neorg_with(module_name, configuration)
    local neorg = require("neorg")

    neorg.setup({
        load = {
            ["core.defaults"] = {},
            [module_name] = { config = configuration },
        },
    })

    return neorg
end

--- Runs a callback in the context of a given file.
---@param filename string The name of the file (used to determine filetype)
---@param content string The content of the buffer.
---@param callback fun(bufnr: number) The function to execute with the buffer number provided.
function tests.in_file(filename, content, callback)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, filename)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(content, "\n"))

    callback(buf)

    vim.api.nvim_buf_delete(buf, { force = true })
end

return tests
