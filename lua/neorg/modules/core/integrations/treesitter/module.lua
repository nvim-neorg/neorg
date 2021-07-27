--[[
	A module designed to integrate TreeSitter into Neorg.

	If it seems that I don't know what I'm doing at times it's because I have no clue what I'm doing.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.integrations.treesitter")

module.setup = function()
	return { success = true, requires = { "core.highlights", "core.mode", "core.keybinds" } }
end

module.config.public = {
	highlights = {
		tag = {
			-- The + tells neorg to link to an existing hl
			begin = "+TSKeyword",

			-- Supply any arguments you would to :highlight here
			-- Example: ["end"] = "guifg=#93042b",
			["end"] = "+TSKeyword",

			name = "+TSKeyword",
			parameters = "+TSType",
			content = "+Normal",
			comment = "+TSComment",
		},

		heading = {
			["1"] = "+TSAttribute",
			["2"] = "+TSLabel",
			["3"] = "+TSMath",
			["4"] = "+TSString",
		},

		error = "+TSError",

		marker = {
			[""] = "+TSLabel",
			title = "+Normal",
		},

		drawer = {
			[""] = "+TSPunctDelimiter",
			title = "+TSMath",
			content = "+Normal"
		},

		escapesequence = "+TSType",

		todoitem = {
			[""] = "+TSCharacter",
			pendingmark = "+TSNamespace",
			donemark = "+TSMethod",
		},

		unorderedlist = "+TSPunctDelimiter",

		quote = {
			[""] = "+TSPunctDelimiter",
			content = "+TSPunctDelimiter",
		},


	}
}

module.load = function()
	module.required["core.mode"].add_mode("traverse-heading")
	module.required["core.keybinds"].register_keybinds(module.name, { "next.heading", "previous.heading" })

	if not module.config.public.highlights.codeblock then
		module.config.public.highlights.codeblock = "guibg=" .. module.required["core.highlights"].dim_color(module.required["core.highlights"].get_background("Normal"), 15)
	end

	module.required["core.highlights"].add_highlights(module.config.public.highlights)

	--[[
		The below code snippet collects all language shorthands and links them to
		their parent language, e.g.:
		"hs" links to the "haskell" TreeSitter parser
		"c++" links to the "cpp" TreeSitter parser

		And so on.
		Injections are generated dynamically
	--]]

	local injections = {}

	local langs = require('neorg.external.helpers').get_language_shorthands(false)

	for language, shorthands in pairs(langs) do
		for _, shorthand in ipairs(shorthands) do
			table.insert(injections, ([[(tag (tag_name) @_tagname (tag_parameters) @_language (tag_content) @content (#eq? @_tagname "code") (#eq? @_language "%s") (#set! "language" "%s"))]]):format(shorthand, language))
		end
	end

	table.insert(injections, [[(tag (tag_name) @_tagname (tag_parameters) @language (tag_content) @content (#eq? @_tagname "code") (#not-eq? @language "norg"))]])

    vim.treesitter.set_query("norg", "injections", table.concat(injections, "\n"))
end

module.public = {
	goto_next_heading = function()
		-- Currently we have this crappy solution because I don't know enough treesitter
		-- If you do know how to hop between TS nodes then please make a PR <3 (or at least tell me)

		local line_number = vim.api.nvim_win_get_cursor(0)[1]

		local lines = vim.api.nvim_buf_get_lines(0, line_number, -1, true)

		for relative_line_number, line in ipairs(lines) do
			local match = line:match("^%s*%*+%s+")

			if match then
				vim.api.nvim_win_set_cursor(0, { line_number + relative_line_number, match:len() })
				break
			end
		end
	end,

	goto_previous_heading = function()
		-- Similar to the previous function I have no clue how to do this in TS lmao
		local line_number = vim.api.nvim_win_get_cursor(0)[1]

		local lines = vim.fn.reverse(vim.api.nvim_buf_get_lines(0, 0, line_number - 1, true))

		for relative_line_number, line in ipairs(lines) do
			local match = line:match("^%s*%*+%s+")

			if match then
				vim.api.nvim_win_set_cursor(0, { line_number - relative_line_number, match:len() })
				break
			end
		end
	end,

	-- @Summary Gets all nodes of a given type from the AST
	-- @Description Retrieves all nodes in the form of a list
	-- @Param  type (string) - the type of node to filter out
	get_all_nodes = function(type)
		local result = {}

		-- Do we need to go through each tree? lol
		vim.treesitter.get_parser(0, "norg"):for_each_tree(function(tree)
			-- Get the root for that tree
			local root = tree:root()

			-- @Summary Function to recursively descend down the syntax tree
			-- @Description Recursively searches for a node of a given type
			-- @Param  node (userdata/treesitter node) - the starting point for the search
			local function descend(node)
				-- Iterate over all children of the node and try to match their type
				for child, _ in node:iter_children() do
					if child:type() == type then
						table.insert(result, child)
					else
						-- If no match is found try descending further down the syntax tree
						for _, child_node in ipairs(descend(child) or {}) do
							table.insert(result, child_node)
						end
					end
				end
			end

			descend(root)
		end)

		return result
	end,

	-- @Summary Returns the first occurence of a node in the AST
	-- @Description Returns the first node of given type if present
	-- @Param  type (string) - the type of node to search for
	get_first_node = function(type)
		local ret = nil

		-- I'm starting to doubt that we need to loop through each tree
		-- Core Devs plz help
		vim.treesitter.get_parser(0, "norg"):for_each_tree(function(tree)
			-- Iterate over all top-level children and attempt to find a match
			for child, _ in tree:root():iter_children() do
				if child:type() == type then
					ret = child
					return
				end
			end
		end)

		return ret
	end,

	get_first_node_recursive = function(type)
		local result

		-- Do we need to go through each tree? lol
		vim.treesitter.get_parser(0, "norg"):for_each_tree(function(tree)
			-- Get the root for that tree
			local root = tree:root()

			-- @Summary Function to recursively descend down the syntax tree
			-- @Description Recursively searches for a node of a given type
			-- @Param  node (userdata/treesitter node) - the starting point for the search
			local function descend(node)
				-- Iterate over all children of the node and try to match their type
				for child, _ in node:iter_children() do
					if child:type() == type then
						return child
					else
						-- If no match is found try descending further down the syntax tree
						local descent = descend(child)
						if descent then
							return descent
						end
					end
				end

				return nil
			end

			result = result or descend(root)
		end)

		return result
	end,

	-- @Summary Returns metadata for a tag
	-- @Description Given a node this function will break down the AST elements and return the corresponding text for certain nodes
	-- @Param  tag_node (userdata/treesitter node) - a node of type tag/carryover_tag
	get_tag_info = function(tag_node, check_parent)
		if not tag_node or (tag_node:type() ~= "tag" and tag_node:type() ~= "carryover_tag") then
			return nil
		end

		-- Grab the TreeSitter utils
		local ts_utils = require('nvim-treesitter.ts_utils')

		local attributes = {}
		local leading_whitespace, resulting_name, params, content = 0, {}, {}, {}

		if check_parent == true or check_parent == nil then
			local parent = tag_node:parent()

			while parent:type() == "carryover_tag" do
				local meta = module.public.get_tag_info(parent, false)

				if vim.tbl_isempty(vim.tbl_filter(function(attribute)
					return attribute.name == meta.name
				end, attributes)) then
					table.insert(attributes, meta)
				else
					log.warn("Two carryover tags with the same name detected, the top level tag will take precedence")
				end
				parent = parent:parent()
			end
		end

		-- Iterate over all children of the tag node
		for child, _ in tag_node:iter_children() do
			-- If we're dealing with the tag name then append the text of the tag_name node to this table
			if child:type() == "tag_name" then
				table.insert(resulting_name, ts_utils.get_node_text(child)[1])
			elseif child:type() == "tag_parameters" then
				table.insert(params, ts_utils.get_node_text(child)[1])
			elseif child:type() == "leading_whitespace" then
				leading_whitespace = ts_utils.get_node_text(child)[1]:len()
			elseif child:type() == "tag_content" then
				-- If we're dealing with tag content then retrieve that content
				content = ts_utils.get_node_text(child)
			end
		end

		content = table.concat(content, "\n")

		local start_row, start_column, end_row, end_column = tag_node:range()

		return { name = table.concat(resulting_name, "."), parameters = params, content = content:sub(2, content:len() - 1), indent_amount = leading_whitespace, attributes = vim.fn.reverse(attributes), start = { row = start_row, column = start_column }, ["end"] = { row = end_row, column = end_column } }
	end,

	-- @Summary Parses data from an @ tag
	-- @Description Used to extract data from e.g. document.meta
	-- @Param  tag_content (string) - the content of the tag (without the beginning and end declarations)
	parse_tag = function(tag_content)
		local result = {}

		tag_content = tag_content:gsub("([^%s])~\n%s*", "%1 ")

		for name, content in tag_content:gmatch("%s*(%w+):%s+([^\n]*)") do
			result[name] = content
		end

		return result
	end,
}

module.on_event = function(event)
	if event.split_type[1] == "core.keybinds" then
		if event.split_type[2] == "core.integrations.treesitter.next.heading" then
			module.public.goto_next_heading()
		elseif event.split_type[2] == "core.integrations.treesitter.previous.heading" then
			module.public.goto_previous_heading()
		end
	end
end

module.events.subscribed = {
	["core.keybinds"] = {
		["core.integrations.treesitter.next.heading"] = true,
		["core.integrations.treesitter.previous.heading"] = true,
	}
}

return module
