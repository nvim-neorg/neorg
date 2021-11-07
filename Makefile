test:
	nvim --headless --noplugin \
	-u tests/custom_init.vim \
	-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/custom_init.vim'}"

ci:
	nvim --noplugin -u tests/custom_init.vim -c "TSUpdateSync norg" -c "qa!" && \
	mkdir -p /tmp/neorg/parser && \
	cp nvim-treesitter/parser/norg.so /tmp/neorg/parser && \
	make test

testfile:
	nvim --headless --noplugin -u tests/custom_init.vim -c "PlenaryBustedFile $(FILE)"

ci-doc:
	nvim --noplugin -u tests/custom_init.vim -c "TSUpdateSync lua" -c "qa!" && \
	mkdir -p /tmp/lua/parser && \
	cp nvim-treesitter/parser/lua.so /tmp/lua/parser && \
	make documentation

documentation:
	nvim --noplugin --headless -u docgen/minimal_init.vim -c "luafile ./docgen/init.lua" -c 'qa'
