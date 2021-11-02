test:
	nvim --headless --noplugin \
	-u tests/custom_init.vim \
	-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/custom_init.vim'}"

ci:
	nvim --noplugin -u tests/custom_init.vim -c "TSUpdateSync norg" -c "qa!" && \
	mkdir -p /tmp/neorg/parser && \
	cp nvim-treesitter/parser/norg.so /tmp/neorg/parser && \
	make test
