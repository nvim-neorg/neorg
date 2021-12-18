-- Generate a simple config file
local config = {}

local path = vim.fn.getcwd()
require("neorg").setup({
    load = {
        ["core.gtd.base"] = {
            config = {
                workspace = "gtd",
            },
        },
        ["core.norg.dirman"] = {
            config = {
                workspaces = {
                    gtd = path .. "/tests/mocks",
                },
            },
        },
    },
})

-- Start neorg
neorg.org_file_entered(false)
neorg.modules.get_module("core.norg.dirman").set_workspace("gtd")

-- Create temporary buffer for quick use in test files
config.temp_buf = neorg.modules.get_module("core.gtd.queries").get_bufnr_from_file("test_file_3.norg")

config.get_void_buf = function()
    return neorg.modules.get_module("core.gtd.queries").get_bufnr_from_file("blank_file.norg")
end

return config
