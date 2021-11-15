" Copied from: https://github.com/ThePrimeagen/refactoring.nvim/blob/master/scripts/minimal.vim

" Current neorg code
set rtp+=.

" For test suites
set rtp+=/tmp/neorg
set rtp+=./plenary.nvim
set rtp+=./nvim-treesitter

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

set noswapfile

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim

lua <<EOF
function P(...)
    local objects = vim.tbl_map(vim.inspect, {...})
    print(unpack(objects))
    return ...
end


local parser_configs = require("nvim-treesitter.parsers").get_parser_configs()

parser_configs.norg = {
    install_info = {
        url = "https://github.com/vhyrro/tree-sitter-norg",
        files = { "src/parser.c", "src/scanner.cc" },
        branch = "main",
    },
}

require('nvim-treesitter.configs').setup({})
-- fixes 'pos_delta >= 0' error - https://github.com/nvim-lua/plenary.nvim/issues/52
vim.cmd('set display=lastline')
EOF

