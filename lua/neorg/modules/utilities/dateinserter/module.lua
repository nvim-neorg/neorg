--[[
    DATEINSERTER
    This module is responsible for handling the insertion of date and time into a neorg buffer.
--]]

require('neorg.modules.base')
require('neorg.events')

local module = neorg.modules.create("utilities.dateinserter")
local log = require('neorg.external.log')

module.setup = function()
	return { success = true, requires = { "core.keybinds" } }
end

module.on_event = function(event)
	if event.split_type[2] == "utilities.dateinserter.insert_datetime" then
		(vim.schedule_wrap(function() module.public.insert_datetime() end))()
	end
end

module.public = {

  version = "0.4",

  insert_datetime = function()
    vim.cmd("put =strftime('%c')")
  end

}

module.events.subscribed = {

  ["core.keybinds"] = {
    ["utilities.dateinserter.insert_datetime"] = true
  }

}

module.config.public = {

	keybinds = {

		["<Leader>oid"] = {
			name = "insert_datetime",
			mode = "n",
			opts = { silent = true }
		}

	}

}

return module
