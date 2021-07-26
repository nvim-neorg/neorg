--[[
	Module designed to tangle your Neorg files into real configs.
	This module is a very much basic implementation, and does not support a lot of things.
	Its here to at least have some basic functionality though.
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

	tangle = function(to, extension, document_metadata)
		local ts = module.required["core.integrations.treesitter"]

		local content = {}

		vim.tbl_map(function(node)
			local meta = ts.get_tag_info(node)

			local tangle_attribs = vim.tbl_filter(function(attribute)
				if attribute.name == "tangle" then
					if vim.tbl_isempty(attribute.parameters) then
						log.error("Expected arguments for $tangle definition at line", meta.start.row)
						return false
					end

					return true
				end
				return false
			end, meta.attributes)

			for _, tangle_attribute in ipairs(tangle_attribs) do
				if tangle_attribute.parameters[1] == "<none>" then
					return
				end
			end

			if meta.name == "code" and meta.parameters[1] and meta.parameters[1] == extension then
				if not vim.tbl_isempty(tangle_attribs) then
					if vim.fn.expand(tangle_attribs[1].parameters[1]) == to or to == "all" then
						content[tangle_attribs[1].parameters[1]] = content[tangle_attribs[1].parameters[1]] or {}
						table.insert(content[tangle_attribs[1].parameters[1]], meta.content)
					end
				elseif to == vim.fn.expand(document_metadata.tangle) or to == "all" then
					content[to] = content[to] or {}
					table.insert(content[to], meta.content)
				end
			end
		end, ts.get_all_nodes("tag"))

		local content_count = vim.fn.len(vim.tbl_values(content))

		if content_count == 0 or (to ~= "all" and not content[to]) then
			vim.notify("No code blocks to tangle")
			return
		end

		local function write_to_file(location, to_write)
			local fullpath = vim.fn.getcwd()

			-- Split the path at every /
			local split = vim.split(vim.trim(location), "/", true)

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

			vim.loop.fs_open(fullpath .. "/" .. split[#split], "w", 438, function(err, fd)
				assert(not err, err)

				vim.loop.fs_write(fd, to_write)
				vim.loop.fs_close(fd)
			end)
		end

		local function perform_tangle(file, to_tangle)
			to_tangle = table.concat(to_tangle, "\n")

			if to:sub(1, 1) == "/" then
				write_to_file(file, to_tangle)
			else
				write_to_file(vim.fn.expand("%:h") .. "/" .. file, to_tangle)
			end
		end

		if to == "all" then
			for file, to_tangle in pairs(content) do
				perform_tangle(file == "all" and document_metadata.tangle or file, to_tangle)
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

	local document_metadata_node = ts.get_first_node_recursive("tag")
	if not document_metadata_node then
		log.error("Unable to tangle current file, document metadata not found.")
		return
	end

	local document_metadata = ts.get_tag_info(document_metadata_node)
	if document_metadata.name ~= "document.meta" then
		log.error("Unable to tangle current file, document metadata not found.")
		return
	end

	local parsed_metadata = ts.parse_tag(document_metadata.content)
	if not parsed_metadata.tangle then
		log.error("Unable to tangle current file, did not find a 'tangle' attribute in the document metadata.")
		return
	end

	local filename = event.content[1] and event.content[1] or parsed_metadata.tangle

	local extension = (function()
		local ret = vim.split(filename == "all" and parsed_metadata.tangle or filename, ".", true)

		if #ret < 2 then
			log.error("Unable to tangle current file, unknown extension.")
			return nil
		end

		return ret[#ret]
	end)()

	if not extension then
		return
	end

	module.public.tangle(filename ~= "all" and filename or filename, extension, parsed_metadata)
end

module.events.subscribed = {
	["core.neorgcmd"] = {
		tangle = true
	}
}

return module
