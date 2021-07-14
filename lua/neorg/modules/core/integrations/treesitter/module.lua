--[[
	A module designed to integrate TreeSitter into Neorg.
	Currently supports assigning custom Neorg highlight groups to real
	colours.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.integrations.treesitter")

module.setup = function()
	return { success = true, requires = { "core.highlights" } }
end

module.load = function()
	module.required["core.highlights"].add_highlights({
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

	})
end

return module
