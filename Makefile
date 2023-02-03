ci-doc:
	nvim -u docgen/minimal_init.vim -c "TSInstall! lua" -c "qa!" && \
	mkdir -p /tmp/lua/parser && \
	cp nvim-treesitter/parser/lua.so /tmp/lua/parser && \
	make documentation

documentation:
	nvim --clean --headless -u docgen/minimal_init.vim -c "luafile ./docgen/init.lua" -c 'qa'

format:
	stylua -v --verify .

install_pre_commit:
	cp scripts/pre-commit "$$(git rev-parse --git-dir)/hooks/"

check:
	luacheck lua/
