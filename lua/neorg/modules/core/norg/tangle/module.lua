--[[
	Module designed to tangle your Neorg files into real configs.
	This module is a very much basic implementation, and does not support a lot of things.
	Its here to at least have some basic functionality though.

	NOTE: This should get a rewrite after 0.1 is released - this is built on the wrong sort of foundation.
	org-babel does this well, tangling exists simply because babel has a deep understanding of the code blocks
	present in the document, compared to simply grabbing all code blocks and spitting them out
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.tangle")

module.setup = function()
	return { success = true, requires = { "core.integrations.treesitter", "core.neorgcmd" } }
end

module.public = {
	neorg_commands = {
		definitions = {
			tangle = {
				__any__ = require('neorg.external.helpers').get_language_list(false)
			}
		},
		data = {
			tangle = {
				min_args = 0,
				max_args = 2,
				name = "tangle"
			}
		}
	},

	-- @Summary Tangles all code blocks to the output file
	-- @Description Grabs all code blocks present in the current document and spits them out to their respective locations
	-- @Param  to (string) - where we want to tangle to
	-- @Param  extension (string) - the extension of the file/the type of code blocks to look for
	-- @Param  document_metadata (table) - the metadata of the current document
	tangle = function(to, extension, document_metadata)
		-- Grab the treesitter integration module
		local ts = module.required["core.integrations.treesitter"]

		-- Store the content and the amount of code blocks parsed
		local content = {}
		local content_count = 0

		-- Iterate through every tag node and try to match it against a code block
		vim.tbl_map(function(node)
			local meta = ts.get_tag_info(node)

			-- If we're dealing with a code block and one with the correct language then
			if meta.name == "code" and meta.parameters[1] and meta.parameters[1] == extension then

				-- Get a list of all $tangle definitions
				local tangle_attribs = vim.tbl_filter(function(attribute)
					-- Filter through all tags that are a tangle tag
					if attribute.name == "tangle" then
						-- If the $tangle carryover tag doesn't have any parameters then it's considered invalid
						if vim.tbl_isempty(attribute.parameters) then
							log.error("Expected arguments for $tangle definition at line", meta.start.row)
							return false
						end

						return true
					end
					return false
				end, meta.attributes)

				-- If any tangle attribute has a parameter of <none> then ignore this current code block by returning
				for _, tangle_attribute in ipairs(tangle_attribs) do
					if tangle_attribute.parameters[1] == "<none>" then
						return
					end
				end

				-- If the tangle attributes aren't empty then
				if not vim.tbl_isempty(tangle_attribs) then
					-- If the location defined in the $tangle tag is the same as the location we want to tangle to then add the code block
					-- to the list of code blocks to tangle for the file specified in $tangle <file>.
 					-- If we have set the location we want to tangle to to <all> then also allow this check to succeed
					if vim.fn.expand(tangle_attribs[1].parameters[1]) == to or to == "<all>" then
						content[tangle_attribs[1].parameters[1]] = content[tangle_attribs[1].parameters[1]] or {}
						table.insert(content[tangle_attribs[1].parameters[1]], meta.content)
					end
				-- Otherwise if no special tangling was present check to see whether the main location set in the metadata is
				-- the same as the location we want to tangle to
				elseif to == vim.fn.expand(document_metadata.tangle) or to == "<all>" then
					-- If it was then add it to the list of code blocks to tangle for that file
					content[to] = content[to] or {}
					table.insert(content[to], meta.content)
				end

				content_count = content_count + 1
			end
		end, ts.get_all_nodes("tag"))

		-- If there's no code blocks to tangle then return
		if content_count == 0 or (to ~= "<all>" and not content[to]) then
			vim.notify("No code blocks to tangle")
			return
		end

	-- @Summary Writes some content to a specific location
	-- @Description Attemps to write content to a file. Also creates nonexistent directories
	-- @Param  location (string) - the location to write to
	-- @Param  to_write (string) - the content to write to the file
		local function write_to_file(location, to_write)
			-- Store the current directory in the fullpath
			local fullpath = vim.fn.getcwd()

			-- Split the path at every /
			local split = vim.split(vim.trim(location), "/", true)

			-- If the file provided isn't an absolute path then
			if location:sub(0, 1) ~= "/" then
				-- If the last element is empty (i.e. if the string provided ends with '/') then trim it
				if split[#split]:len() == 0 then
					split = vim.list_slice(split, 0, #split - 1)
				end

				-- Go through each directory (excluding the actual file name) and create each directory individually
				for _, element in ipairs(vim.list_slice(split, 0, #split - 1)) do
					if not vim.startswith(element, ".") then
						vim.loop.fs_mkdir(fullpath .. "/" .. element, 16877)
						fullpath = fullpath .. "/" .. element
					end
				end
			end

			-- Open the file and write the contents to it
			vim.loop.fs_open(fullpath .. "/" .. split[#split], "w", 438, function(err, fd)
				assert(not err, err)

				vim.loop.fs_write(fd, to_write)
				vim.loop.fs_close(fd)
			end)
		end

		-- @Summary Tangles a set of code blocks to the specified file
		-- @Param  file (string) - the location to write to
		-- @Param  to_tangle (table) - a list of strings being the code blocks to tangle
		local function perform_tangle(file, to_tangle)
			-- Concatenate all values from the to_tangle table together
			to_tangle = table.concat(to_tangle, "\n")

			-- If we're dealing with a full path then provide the filepath as-is, otherwise expand it and provide the fullpath ourselves
			if to:sub(1, 1) == "/" then
				write_to_file(file, to_tangle)
			else
				write_to_file(vim.fn.expand("%:h") .. "/" .. file, to_tangle)
			end
		end

		-- If we told Neorg to tangle all files then perform a tangle on all of them, otherwise just tangle the content to be tangle to the
		-- "to" location
		if to == "<all>" then
			for file, to_tangle in pairs(content) do
				perform_tangle(file == "<all>" and document_metadata.tangle or file, to_tangle)
			end

			vim.schedule(function()
				vim.notify("Successfully tangled " .. content_count .. " code blocks to several files")
			end)
		else
			perform_tangle(to, content[to])

			vim.schedule(function()
				vim.notify("Successfully tangled " .. content_count .. " code blocks to " .. to)
			end)
		end
	end
}

module.on_event = function(event)
	local ts = module.required["core.integrations.treesitter"]

	-- Get the first tag in the document
	local document_metadata_node = ts.get_first_node_recursive("tag")
	-- If no such tag is present then throw an error, we need document metadata in order for us to work as expected
	if not document_metadata_node then
		log.error("Unable to tangle current file, document metadata not found.")
		return
	end

	-- Extract as much information as we can from the first node in the document
	local document_metadata = ts.get_tag_info(document_metadata_node)

	-- If that tag is not the document metadata then error out
	if document_metadata.name ~= "document.meta" then
		log.error("Unable to tangle current file, document metadata not found.")
		return
	end

	-- Parse the content of the metadata tag and return it
	-- Check to see whether there is a "tangle" key, otherwise error out
	local parsed_metadata = ts.parse_tag(document_metadata.content)
	if not parsed_metadata.tangle then
		log.error("Unable to tangle current file, did not find a 'tangle' attribute in the document metadata.")
		return
	end

	-- If we provided an extra argument to :Neorg tangle then use that as the filename, otherwise use the filepath provided
	-- in the document's metadata
	local filename = event.content[1] and event.content[1] or parsed_metadata.tangle

	-- Extract the extension from the filename
	local extension = (function()
		local ret = vim.split(filename == "<all>" and parsed_metadata.tangle or filename, ".", true)

		if #ret < 2 then
			log.error("Unable to tangle current file, unknown extension.")
			return nil
		end

		return ret[#ret]
	end)()

	-- If we couldn't extract an extension then bail
	if not extension then
		return
	end

	-- Kickstart the tangling process
	module.public.tangle(filename ~= "<all>" and filename or filename, extension, parsed_metadata)
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		tangle = true
	}
}

return module
