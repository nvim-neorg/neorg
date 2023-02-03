" Copied from: https://github.com/ThePrimeagen/refactoring.nvim/blob/master/scripts/minimal.vim

" Current neorg code
set rtp+=..

" For test suites
set rtp+=../plenary.nvim
set rtp+=../nvim-treesitter

set noswapfile

lua << EOF
P = function(...)
    print(vim.inspect(...))
end

local ok, module = pcall(require,'nvim-treesitter.configs')
if ok then
    module.setup({})
end

package.path = "../lua/?.lua;" .. package.path
EOF

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim
