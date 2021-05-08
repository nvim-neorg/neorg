--[[
-- GitHub installer for neorg modules (WIP)
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.neorgcmd.commands.install")

local log = require('neorg.external.log')

module.config.public = {

	neorg_commands = {
		definitions = {
			install = {}
		},
		data = {
			install = {
				min_args = 1,
				name = "install"
			}
		}
	}

}

module.on_event = function(event)

	-- We know that the only event we will be receiving will be the install event, since that's the only event we're subscribed to

	local shortened_git_address = (function()
		local res = ""
		for i, string in ipairs(event.content) do res = res .. string .. (i < #event.content and " " or "") end
		return res
	end)()

	local split_git_address = vim.split(shortened_git_address, "/", true)

	if #split_git_address ~= 2 then
		log.error("Unable to pull module", shortened_git_address, "- invalid repo syntax.")
		return
	end

	local path = vim.fn.stdpath("cache") .. "/neorg_community_modules/" .. split_git_address[2]
	local install = vim.fn.isdirectory(path) == 0

	-- You may be screaming right now thinking "you literally have plenary, why do you use libuv?"
	-- The basic answer is plenary causes git to always fail with error code 128. Got no clue why,
	-- don't ask me. This works tho! If you have a solution, make a PR please!

	local handle

	handle = vim.loop.spawn("git", {

		args = install and { "clone", "https://github.com/" .. shortened_git_address, path } or { "-C", path, "pull" }

	}, function(error_code)

		if error_code ~= 0 then
			log.error("Failed to grab", shortened_git_address, "from github - error code", error_code, "was returned.")
			handle:close()
			return
		end

		package.path = package.path .. ";" .. path;

		(vim.schedule_wrap(function() vim.api.nvim_echo({ { install and ("Successfully installed ") or ("Successfully updated ") .. split_git_address[2] .. "!" } }, false, {}) end))()

		handle:close()
	end);

	(vim.schedule_wrap(function() vim.api.nvim_echo({ { "Pulling module from github.com/" .. shortened_git_address .. "..." } }, false, {}) end))()

end

module.events.subscribed = {
	["core.neorgcmd"] = {
		install = true
	}
}

return module
