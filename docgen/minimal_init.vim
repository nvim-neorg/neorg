" Copied from: https://github.com/ThePrimeagen/refactoring.nvim/blob/master/scripts/minimal.vim

" Current neorg code
set rtp+=.

set rtp+=./nvim-treesitter

set noswapfile

runtime! plugin/nvim-treesitter.vim

lua << EOF
require("nvim-treesitter").setup({})

local ok, module = pcall(require,'nvim-treesitter.configs')
if ok then
    module.setup({})
end

package.path = "../lua/?.lua;" .. "../lua/?/init.lua;" .. package.path
package.path = "../nvim-treesitter/lua/?.lua;" .. package.path
package.path = "/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;" .. package.path
package.path = "/usr/share/lua/5.1/?.so;" .. package.path

vim.cmd.TSInstallSync({
    bang = true,
    args = { "lua", "norg" },
})
EOF
