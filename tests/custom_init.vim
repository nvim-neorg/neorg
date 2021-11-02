" Copied from: https://github.com/ThePrimeagen/refactoring.nvim/blob/master/scripts/minimal.vim

" Current neorg code
set rtp+=.

" For test suites
set rtp+=../plenary.nvim
set rtp+=../nvim-treesitter

" If you use vim-plug if you got it locally
set rtp+=~/.vim/plugged/plenary.nvim
set rtp+=~/.vim/plugged/nvim-treesitter
set rtp+=~/.vim/plugged/neorg

" If you are using packer
set rtp+=~/.local/share/nvim/site/pack/packer/start/plenary.nvim
set rtp+=~/.local/share/nvim/site/pack/packer/start/nvim-treesitter
set rtp+=~/.local/share/nvim/site/pack/packer/start/neorg
set rtp+=~/.local/share/nvim/site/pack/packer/opt/plenary.nvim
set rtp+=~/.local/share/nvim/site/pack/packer/opt/nvim-treesitter
set rtp+=~/.local/share/nvim/site/pack/packer/opt/neorg

lua <<EOF
local parser_configs = require("nvim-treesitter.parsers").get_parser_configs()

parser_configs.norg = {
    install_info = {
        url = "https://github.com/vhyrro/tree-sitter-norg",
        files = { "src/parser.c", "src/scanner.cc" },
        branch = "main",
    },
}

local installed_parsers = require'nvim-treesitter.info'.installed_parsers()

-- fixes 'pos_delta >= 0' error - https://github.com/nvim-lua/plenary.nvim/issues/52
vim.cmd('set display=lastline')
if not vim.tbl_contains(installed_parsers, 'norg') then
  vim.cmd 'runtime! plugin/nvim-treesitter.vim'
  vim.cmd('TSInstallSync norg')
end
EOF
