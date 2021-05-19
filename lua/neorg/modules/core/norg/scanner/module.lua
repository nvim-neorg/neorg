--[[
--	NORG FILE SCANNER FOR NEORG
--	Scans a .norg file and converts it into an array of tokens.
--	Allows for interacting with said tokenized data.
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.scanner")

module.setup = function()
	return { success = true, requires = { "core.autocommands" } }
end

module.private = {
	tokens = {
		--[[
			["buffer_name"] = {
				<tokens_here>
			}
		--]]
	},

	current_tokens = nil, -- Pointer to one of the defined tables in module.private.tokens

	scanner_position = 0, -- The position of the scanner in the document

	buffer_contents = "", -- The contents of the current buffer that's being parsed

}

module.load = function()
	-- Listen for the BufEnter event (reparse the document upon entering it)
	module.required["core.autocommands"].enable_autocommand("BufEnter")
end

module.public = {

	-- @Summary Parses a buffer from its ID
	-- @Description Parses the whole buffer and converts it into an array of tokens. These tokens can the be used by core.norg.parser to convert the file into a syntax tree.
	-- @Param  buffer_id (number) - the ID of the buffer to scan
	parse_buffer = function(buffer_id)
		-- Grab the contents of the whole buffer
		module.private.buffer_contents = table.concat(vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false), "\n")

		-- Get the name of the buffer with our ID
		local buffer_name = vim.api.nvim_buf_get_name(buffer_id)

		-- Reset the tokens for our buffer
		module.private.tokens[buffer_name] = {}

		-- Store where the previous token was found
		local previous_token_pos = 0

		-- Reset the scanner position back to 0
		module.private.scanner_position = 0

	-- @Summary Inserts a token into the buffer's token array
	-- @Description If the token is not empty, insert it into the buffer's token array, else do nothing.
	-- @Param  token (string) - the token to insert
		local insert_token = function(token)
			if token:len() == 0 then return end

			table.insert(module.private.tokens[buffer_name], token)
		end

	-- @Summary Detects a token from the current scanner position
	-- @Description Performs a test to see whether the string located at the scanner position matches the provided token.
	-- @Param  token (string) - the token to test against
		local detect_token = function(token)
			local search = module.private.buffer_contents:sub(module.private.scanner_position, module.private.scanner_position + token:len() - 1)

			if search == token then
				insert_token(module.private.buffer_contents:sub(previous_token_pos, module.private.scanner_position - 1))
				insert_token(search)

				module.public.next_char()
				previous_token_pos = module.private.scanner_position + token:len() - 1
				return true
			end

			return false
		end

		-- While the scanner hasn't reached the end of the file
		while module.private.scanner_position ~= module.private.buffer_contents:len() + 1 do
			-- Detect all of the below tokens
			if not detect_token("\n") and not detect_token("\r\n")
				and not detect_token("*")
				and not detect_token("[")
				and not detect_token("]")
				and not detect_token("(")
				and not detect_token(")")
				and not detect_token("_")
				and not detect_token("/")
				and not detect_token("-")
				and not detect_token(">")
				and not detect_token("`")
				and not detect_token("@")
				and not detect_token("end")
			then
				-- If no tokens could be found for that scanner position move along
				module.public.next_char()
			end
		end

		-- After parsing the whole document add the remainder of the document to the token list
		insert_token(module.private.buffer_contents:sub(previous_token_pos))

		-- Set the current_tokens pointer to the current buffer's tokens
		module.private.current_tokens = module.private.tokens[buffer_name]
	end,

	-- @Summary Advance a character forward
	-- @Description Increase the scanner position by one
	next_char = function()
		module.private.scanner_position = module.private.scanner_position + 1
	end,

	-- @Summary Get the current character
	-- @Description Returns the current character from the current scanner position
	current_char = function()
		return module.private.buffer_contents:sub(module.private.scanner_position, module.private.scanner_position)
	end,

	-- @Summary Gets the tokens for the current buffer
	get_tokens = function()
		return module.private.current_tokens
	end

}

module.on_event = function(event)
	-- If the event we've received is the BufEnter events then
	if event.type == "core.autocommands.events.bufenter" then
		-- If we already have tokens available for the current buffer don't bother reparsing
		if module.private.tokens[vim.api.nvim_buf_get_name(0)] then
			module.private.current_tokens = module.private.tokens[vim.api.nvim_buf_get_name(0)]
		else
			-- Else reparse the buffer
			module.public.parse_buffer()
		end
	end
end

module.events.subscribed = {
	["core.autocommands"] = {
		bufenter = true
	}
}

return module
