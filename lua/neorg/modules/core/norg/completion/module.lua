--[[
	A wrapper to interface with several different completion engines.
--]]

require('neorg.modules.base')
require('neorg.modules')

local module = neorg.modules.create("core.norg.completion")

module.config.public = {
	-- We currently only support compe
	engine = "compe",
	name = "[Neorg]",
}

module.private = {
	engine = nil
}

module.load = function()
	if module.config.public.engine == "compe" and neorg.modules.load_module("core.integrations.nvim-compe") then
		module.private.engine = neorg.modules.get_module("core.integrations.nvim-compe")
	else
		log.error("Unable to load completion module -", module.config.public.engine, "is not a recognized engine.")
		return
	end

	module.private.engine.invoke_completion_engine = function(context)
		return module.public.complete(context)
	end

	module.private.engine.create_source({
		completions = module.config.public.completions
	})
end

module.public = {

	-- Define completions
	completions = {
		{ -- Create a new completion
			-- Define the regex that should match in order to proceed
			regex = "^%s*[@$]",

			-- If regex can be matched, this item then gets verified via TreeSitter's AST
			node = function(_, previous)
				-- If no previous node exists then show autocompletions
				if not previous then
					return true
				end

				-- If the previous node is not tag parameters or the tag name
				-- (i.e. we are not inside of a tag) then show autocompletions
				return previous:type() ~= "tag_parameters" and previous:type() ~= "tag_name"
			end,

			-- The actual elements to show if the above tests were true
			complete = {
				"table",
				"comment",
				"unordered",
				"code",
			},

			-- Additional options to pass to the completion engine
			options = {
				type = "Tag",
			},

			-- We might have matched the top level item, but can we match it with any
			-- more precision? Descend down the rabbit hole and try to more accurately match
			-- the line.
			descend = {
				-- The cycle continues
				{
					-- Define a regex (gets appended to parent's regex)
					regex = "code%s+%w*",
					-- No node variable, we don't need that sort of check here

					-- Completions {{{
					complete = {
						"1c",
						"4d",
						"abnf",
						"accesslog",
						"ada",
						"arduino",
						"ino",
						"armasm",
						"arm",
						"avrasm",
						"actionscript",
						"as",
						"alan",
						"i",
						"ln",
						"angelscript",
						"asc",
						"apache",
						"apacheconf",
						"applescript",
						"osascript",
						"arcade",
						"asciidoc",
						"adoc",
						"aspectj",
						"autohotkey",
						"autoit",
						"awk",
						"mawk",
						"bash",
						"sh",
						"basic",
						"bbcode",
						"blade",
						"bnf",
						"brainfuck",
						"bf",
						"csharp",
						"cs",
						"c",
						"h",
						"cpp",
						"hpp",
						"cal",
						"cos",
						"cls",
						"cmake",
						"cmake.in",
						"coq",
						"csp",
						"css",
						"capnproto",
						"capnp",
						"chaos",
						"kaos",
						"chapel",
						"chpl",
						"cisco",
						"clojure",
						"clj",
						"coffeescript",
						"coffee",
						"cpc",
						"crmsh",
						"crm",
						"crystal",
						"cr",
						"cypher",
						"d",
						"dns",
						"zone",
						"dos",
						"bat",
						"dart",
						"dpr",
						"dfm",
						"diff",
						"patch",
						"django",
						"jinja",
						"dockerfile",
						"docker",
						"dsconfig",
						"dts",
						"dust",
						"dst",
						"dylan",
						"ebnf",
						"elixir",
						"elm",
						"erlang",
						"erl",
						"excel",
						"xls",
						"extempore",
						"xtlang",
						"fsharp",
						"fs",
						"fix",
						"fortran",
						"f90",
						"gcode",
						"nc",
						"gams",
						"gms",
						"gauss",
						"gss",
						"godot",
						"gdscript",
						"gherkin",
						"hbs",
						"glimmer",
						"gn",
						"gni",
						"go",
						"golang",
						"gf",
						"golo",
						"gololang",
						"gradle",
						"groovy",
						"xml",
						"html",
						"http",
						"https",
						"haml",
						"handlebars",
						"hbs",
						"haskell",
						"hs",
						"haxe",
						"hx",
						"hlsl",
						"hy",
						"hylang",
						"ini",
						"toml",
						"inform7",
						"i7",
						"irpf90",
						"json",
						"java",
						"jsp",
						"javascript",
						"js",
						"jolie",
						"iol",
						"julia",
						"julia-repl",
						"kotlin",
						"kt",
						"tex",
						"leaf",
						"lean",
						"lasso",
						"less",
						"ldif",
						"lisp",
						"livecodeserver",
						"livescript",
						"lua",
						"makefile",
						"mk",
						"markdown",
						"md",
						"mathematica",
						"mma",
						"matlab",
						"maxima",
						"mel",
						"mercury",
						"mirc",
						"mrc",
						"mizar",
						"mojolicious",
						"monkey",
						"moonscript",
						"moon",
						"n1ql",
						"nsis",
						"never",
						"nginx",
						"nginxconf",
						"nim",
						"nimrod",
						"nix",
						"ocl",
						"ocaml",
						"objectivec",
						"mm",
						"glsl",
						"openscad",
						"scad",
						"ruleslanguage",
						"oxygene",
						"pf",
						"pf.conf",
						"php",
						"papyrus",
						"psc",
						"parser3",
						"perl",
						"pl",
						"plaintext",
						"txt",
						"pony",
						"pgsql",
						"postgres",
						"powershell",
						"ps",
						"processing",
						"prolog",
						"properties",
						"protobuf",
						"puppet",
						"pp",
						"python",
						"py",
						"profile",
						"python-repl",
						"pycon",
						"qsharp",
						"k",
						"kdb",
						"qml",
						"r",
						"cshtml",
						"razor",
						"reasonml",
						"re",
						"redbol",
						"rebol",
						"rib",
						"rsl",
						"risc",
						"riscript",
						"graph",
						"instances",
						"robot",
						"rf",
						"rpm-specfile",
						"rpm",
						"ruby",
						"rb",
						"rust",
						"rs",
						"SAS",
						"sas",
						"scss",
						"sql",
						"p21",
						"step",
						"scala",
						"scheme",
						"scilab",
						"sci",
						"shexc",
						"shell",
						"console",
						"smali",
						"smalltalk",
						"st",
						"sml",
						"solidity",
						"sol",
						"spl",
						"stan",
						"stanfuncs",
						"stata",
						"iecst",
						"scl",
						"stylus",
						"styl",
						"subunit",
						"supercollider",
						"sc",
						"svelte",
						"swift",
						"tcl",
						"tk",
						"terraform",
						"tf",
						"tap",
						"thrift",
						"tp",
						"tsql",
						"twig",
						"craftcms",
						"typescript",
						"ts",
						"unicorn",
						"vbnet",
						"vb",
						"vba",
						"vbscript",
						"vbs",
						"vhdl",
						"vala",
						"verilog",
						"v",
						"vim",
						"axapta",
						"x++",
						"x86asm",
						"xl",
						"tao",
						"xquery",
						"xpath",
						"yml",
						"yaml",
						"zenscript",
						"zs",
						"zephir",
						"zep",
					},
					-- }}}

					-- Extra options
					options = {
						type = "Language"
					},

					-- Don't descend any further, we've narrowed down our match
					descend = {}
				}
			}
		},
		{
			regex = "^%s*@",
			node = function(_, previous, next, utils)
				if not previous then return false end

				return (previous:type() == "tag_parameters" or previous:type() == "tag_name") and next:type() == "tag_end" and vim.tbl_isempty(utils.get_node_text(next, 0))
			end,

			complete = {
				"end"
			},

			options = {
				type = "Directive"
			}
		},
		{
			regex = "^%s*%-%s+%[",

			complete = {
				"[ ] ",
				"[*] ",
				"[x] ",
			},

			options = {
				type = "TODO",
				pre = function()
					local sub = vim.api.nvim_get_current_line():gsub("^(%s*%-%s+%[%s*)%]", "%1")

					if sub then
						vim.api.nvim_set_current_line(sub)
					end
				end,
			}
		}
	},

	complete = function(context, prev, saved)
		saved = saved or ""

		local completions = prev or module.public.completions

		for _, completion_data in ipairs(completions) do
			local ret_completions = { items = completion_data.complete, options = completion_data.options }

			if completion_data.regex then
				local match = context.line:match(saved .. completion_data.regex .. "$")
				if match then
					ret_completions.match = match

					if completion_data.node then
						local ts = require('nvim-treesitter.ts_utils')

						if type(completion_data.node) == "string" then
							local split = vim.split(completion_data.node, "|")
							local negate = split[1]:sub(0, 1) == "!"

							if negate then
								split[1] = split[1]:sub(2)
							end

							if split[2] then
								if split[2] == "prev" then

									local previous_node = ts.get_previous_node(ts.get_node_at_cursor(), true, true)

									if not previous_node then
										if negate then
											return ret_completions
										end

										goto continue
									end

									if not negate and previous_node:type() == split[1] then
										return ret_completions
									elseif negate and previous_node:type() ~= split[1] then
										return ret_completions
									else
										goto continue
									end
								end
							else
								if ts.get_node_at_cursor():type() == split[1] then
									if not negate then
										return ret_completions
									else
										goto continue
									end
								end
							end
						elseif type(completion_data.node) == "function" then
							local current_node = ts.get_node_at_cursor()
							local next_node = ts.get_next_node(current_node, true, true)
							local previous_node = ts.get_previous_node(current_node, true, true)

							if completion_data.node(current_node, previous_node, next_node, ts) == true then
								return ret_completions
							end

							if completion_data.descend then
								local descent = module.public.complete(context, completion_data.descend, saved .. completion_data.regex)

								if not vim.tbl_isempty(descent.items) then
									return descent
								end
							end

							goto continue
						end
					end

					return ret_completions
				elseif completion_data.descend then
					local descent = module.public.complete(context, completion_data.descend, saved .. completion_data.regex)

					if not vim.tbl_isempty(descent.items) then
						return descent
					end
				end
			end

			::continue::
		end

		return { items = {}, options = {} }
	end
}

return module
