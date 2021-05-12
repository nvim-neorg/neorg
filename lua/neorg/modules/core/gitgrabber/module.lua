--[[
--	GITHUB GRABBER FOR NEORG
--	This module is responsible for loading or updating remote repositories on the user's local filesystem
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.gitgrabber")

local log = require('neorg.external.log')

module.config.private = {
	tracked_repos = {} -- Used to track repos
}

module.public = {

	-- @Summary Track a new repo
	-- @Description Adds a new repo to the list of tracked repos. Whenever a repo is tracked it can be easily installed and updated
	-- @Param  repo (string) - a shortened git address like/this
	-- @Param  location (string) - path where to store the repo
	track = function(repo, location)
		module.config.private.tracked_repos[repo] = location
	end,

	-- @Summary Tracks and installs/updates a repo
	-- @Description Adds the repo to the list of tracked repos. If the repo already exists it is updated, else it is grabbed from github and put into its respective location on disk.
	-- @Param  repo (string) - a shortened git address like/this
	-- @Param  location (string) - path where to store the repo
	-- @Param  verification (function(install_location) -> directory (string), error (string)) - function to verify whether the installed repo is valid and meets the requirements. The function returns two values, the directory which should exist in order for the repo to be considered valid and the error message in case the directory doesn't exist.
	manage = function(repo, location, verification)

		-- Split the git address into two. If the address doesn't split into two then that means it's an invalid repo
		local split_git_address = vim.split(repo, "/", true)

		if #split_git_address ~= 2 then
			log.error("Unable to pull module", repo, "- invalid repo syntax.")
			return false
		end

		local path = location .. "/" .. split_git_address[2]

		if not module.public.invoke_git(split_git_address, location, vim.fn.isdirectory(path) == 1 and { "-C", path, "pull" } or { "clone", "https://github.com/" .. repo, path }, verification) then
			return false
		end

		module.config.private.tracked_repos[repo] = location
		return true
	end,

	-- @Summary Updates a repo from a specific location
	-- @Description Invokes the git pull command from the specified location
	-- @Param  location (string) - path where to store the repo
	-- @Param  verification (function(install_location) -> directory (string), error (string)) - function to verify whether the installed repo is valid and meets the requirements. The function returns two values, the directory which should exist in order for the repo to be considered valid and the error message in case the directory doesn't exist.
	update = function(location, verification)
		-- Split the location path
		local split_location = vim.split(location, "/", true)
		-- Invoke the git pull command in the specified directory
		return module.public.invoke_git({ "null", split_location[#split_location] }, location, { "-C", location, "pull" }, verification)
	end,

	-- @Summary Updates all tracked modules
	-- @Description Loops through all tracked repos and invokes the manage() function on them one by one
	update_all = function()
		for repo, location in pairs(module.config.private.repos) do
			module.public.manage(repo, location)
		end
	end,

	-- @Summary Invokes the git program
	-- @Description Calls the git program with the specified arguments and performs the verification check.
	-- @Param  split_repo (string[2]) - if the repo we want is i.e. some/repo, then this value should be vim.split("some/repo", "/", true (string) - path to where store the repo)
	-- @Param  location (string) - path where to store the repo
	-- @Param  args (table) - the table to be passed into the git command via vim.loop.spawn
	-- @Param  verification (function(install_location) -> directory (string), error (string)) - function to verify whether the installed repo is valid and meets the requirements. The function returns two values, the directory which should exist in order for the repo to be considered valid and the error message in case the directory doesn't exist.
	invoke_git = function(split_repo, location, args, verification)

		-- You may be screaming right now thinking "you literally have plenary, why do you use libuv?"
		-- The basic answer is plenary causes git to always fail with error code 128. Got no clue why,
		-- don't ask me. This works tho! If you have a solution, make a PR please!

		-- Eventuate the info message. We use nvim_echo to make sure the user sees the message in the command bar
		(vim.schedule_wrap(function() vim.api.nvim_echo({ { "Pulling " .. split_repo[2] .. " from github..."} }, false, {}) end))()

		local handle

		handle = vim.loop.spawn("git", {

			args = args

		}, function(error_code)

			-- If we've failed display an error message
			if error_code ~= 0 then
				log.error("Failed to grab", split_repo[2], "from github - error code", error_code, "was returned.")
				handle:close()
				return
			end

			-- Add the installed module to the package path
			package.path = package.path .. ";" .. location .. "/?.lua";

			-- If the verification function exists and is valid then verify whether the installed repo is valid.
			if verification and type(verification) == "function" then
				local file, error = verification(location .. "/" .. split_repo[2]);
				(vim.schedule_wrap(function()
					if vim.fn.isdirectory(file) == 0 then
						log.error("Unable to grab module", split_repo[2], "-", error)
						return
					end
				end))()
			end

			-- Issue the success message. We use nvim_echo to make sure the user sees the message in the command bar
			(vim.schedule_wrap(function() vim.api.nvim_echo({ { "Successfully installed/updated " .. split_repo[2] .. "!"} }, false, {}) end))()

			handle:close()
		end)
	end
}

return module
