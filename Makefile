documentation:
	nvim --headless -u docgen/minimal_init.vim -c "cd ./docgen" -c "source init.lua" -c 'qa'

local-documentation:
	nvim --headless -c "cd ./docgen" -c "source init.lua" -c 'qa'

format:
	stylua -v --verify .

check:
	luacheck lua/
