" Copied from: https://github.com/ThePrimeagen/refactoring.nvim/blob/master/scripts/minimal.vim

" Current neorg code
set rtp+=.

" For test suites
set rtp+=./plenary.nvim
set rtp+=./nvim-treesitter

set noswapfile

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim

lua << EOF
require("nvim-treesitter").setup({})

local ok, module = pcall(require,'nvim-treesitter.configs')
if ok then
    module.setup({})
end

package.path = "../lua/?.lua;" .. package.path
package.path = "../plenary.nvim/lua/?.lua;" .. package.path
package.path = "../nvim-treesitter/lua/?.lua;" .. package.path

vim.cmd.TSInstallSync({
    bang = true,
    args = { "lua" },
})
EOF
