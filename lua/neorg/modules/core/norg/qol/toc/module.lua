--[[
	A Neorg module designed to generate tables of content.
USAGE:
	Invoking the module.public.generate_toc() will simply generate the table of contents and paste it
	under the cursor, that's it!
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.qol.toc")

module.setup = function()
	return { success = true, requires = { "core.keybinds", "core.integrations.treesitter" } }
end

module.load = function()
	module.required["core.keybinds"].register_keybind(module.name, "generate.toc")
end

module.config.public = {
	top_level_message = "Table of Contents"
}

module.public = {
	-- @Summary Generates a ToC
	-- @Description When invoked will generate a table of contents and place it under the cursor
	generate_toc = function()
		local nodes = {}

		-- Go through each node in the syntax tree, if it's type begins with "heading" then include it
		module.required["core.integrations.treesitter"].tree_map(function(child)
			if vim.startswith(child:type(), "heading") then
				-- We do these weird checks here because some heading types can have a "leading_whitespace" node
				table.insert(nodes, { child:type(), require('nvim-treesitter.ts_utils').get_node_text(child:named_child(1):type() == "paragraph_segment" and child:named_child(1) or child:named_child(2)) })
			end
		end)

		-- The actual generated ToC
		local result = {
			"* " .. module.config.public.top_level_message, -- By default "* Table Of Contents"
		}

		-- Go through each node
		for _, node_info in ipairs(nodes) do
			-- Construct an indent level by reading the last character of the node type (e.g. heading1/heading2)
			-- and by converting it into a real number
			local actual_level = tonumber(node_info[1]:sub(node_info[1]:len(), node_info[1]:len()))
			local level = actual_level * 2 - 2

			-- If there is an excessive empty string then remove that element from the node info
			if node_info[2][#node_info[2]]:len() == 0 then
				node_info[2][#node_info[2]] = nil
			end

			-- Grab the content of the node and remove and trailing modifiers
			local content = table.concat(node_info[2], " "):gsub("~%s+", " ")

			-- Insert the result to this table
			table.insert(result, (" "):rep(level) .. "-> [" .. content:gsub(":$", "") .. "](" .. ("*"):rep(actual_level) .. content .. ")")
		end

		-- Paste the result under the cursor
		vim.api.nvim_put(result, "l", true, false)
	end
}

module.on_event = function(event)
	if event.split_type[2] == "core.norg.qol.toc.generate.toc" then
		module.public.generate_toc()
	end
end

module.events.subscribed = {
	["core.keybinds"] = {
		["core.norg.qol.toc.generate.toc"] = true
	}
}

return module
