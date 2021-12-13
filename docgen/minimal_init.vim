" Copied from: https://github.com/ThePrimeagen/refactoring.nvim/blob/master/scripts/minimal.vim

" Current neorg code
set rtp+=.

" For test suites
set rtp+=/tmp/lua
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

" If you are using minpac
set rtp+=~/.config/nvim/pack/minpac/start/plenary.nvim
set rtp+=~/.config/nvim/pack/minpac/start/nvim-treesitter
set rtp+=~/.config/nvim/pack/minpac/start/neorg
set rtp+=~/.config/nvim/pack/minpac/opt/plenary.nvim
set rtp+=~/.config/nvim/pack/minpac/opt/nvim-treesitter
set rtp+=~/.config/nvim/pack/minpac/opt/neorg

set noswapfile

lua << EOF
P = function(...)
    print(vim.inspect(...))
end

require('nvim-treesitter.configs').setup({})
EOF

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim
