documentation:
	nvim --headless -u docgen/minimal_init.vim -c "cd ./docgen" -c "source init.lua" -c 'qa'

local-documentation:
	nvim --headless -c "cd ./docgen" -c "source init.lua" -c 'qa'

format:
	stylua -v --verify .

check:
	nix flake check

shell:
	nix develop

integration-test:
	nix run ".#integration-test"

test:
	LUA_PATH="$(shell luarocks path --lr-path --lua-version 5.1 --local)" \
	LUA_CPATH="$(shell luarocks path --lr-cpath --lua-version 5.1 --local)" \
	luarocks test --local --lua-version 5.1
