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

	-- Concatenate the arguments we have received from :Neorg install into the full shortened git address
	local shortened_git_address = (function()
		local res = ""
		for i, string in ipairs(event.content) do res = res .. string .. (i < #event.content and " " or "") end
		return res
	end)()

	-- Split the git address into two. If the address doesn't split into two then that means it's an invalid repo
	local split_git_address = vim.split(shortened_git_address, "/", true)

	if #split_git_address ~= 2 then
		log.error("Unable to pull module", shortened_git_address, "- invalid repo syntax.")
		return
	end

	-- Define where we are going to install the community-made module
	local path = vim.fn.stdpath("cache") .. "/neorg_community_modules/" .. split_git_address[2]

	-- Check whether the module already exists, if it doesn't set this install option to true
	local install = vim.fn.isdirectory(path) == 0

	-- You may be screaming right now thinking "you literally have plenary, why do you use libuv?"
	-- The basic answer is plenary causes git to always fail with error code 128. Got no clue why,
	-- don't ask me. This works tho! If you have a solution, make a PR please!

	local handle

	handle = vim.loop.spawn("git", {

		-- If we are installing the module for the first time then clone the repo, else pull updates
		args = install and { "clone", "https://github.com/" .. shortened_git_address, path } or { "-C", path, "pull" }

	}, function(error_code)

		-- If we've failed display an error message
		if error_code ~= 0 then
			log.error("Failed to grab", shortened_git_address, "from github - error code", error_code, "was returned.")
			handle:close()
			return
		end

		-- Add the installed module to the package path
		package.path = package.path .. ";" .. path .. "/?.lua";

		-- Issue the success message. We use nvim_echo to make sure the user sees the message in the command bar
		(vim.schedule_wrap(function() vim.api.nvim_echo({ { install and ("Successfully installed ") or ("Successfully updated ") .. split_git_address[2] .. "!" } }, false, {}) end))()

		handle:close()
	end);

	-- Since the above git command will run asynchronously we can be sure that this echo will happen before anything from within vim.loop.spawn
	(vim.schedule_wrap(function() vim.api.nvim_echo({ { "Pulling module from github.com/" .. shortened_git_address .. "..." } }, false, {}) end))()

end

module.events.subscribed = {
	["core.neorgcmd"] = {
		install = true
	}
}

return module
