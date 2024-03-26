--[[
    file: Dirman-Utils
    summary: A set of utilities for the `core.dirman` module.
    internal: true
    ---
This internal submodule implements some basic utility functions for [`core.dirman`](@core.dirman).
Currently the only exposed API function is `expand_path`, which takes a path like `$name/my/location` and
converts `$name` into the full path of the workspace called `name`.
--]]

local neorg = require("neorg.core")
local log, modules = neorg.log, neorg.modules

local module = neorg.modules.create("core.dirman.utils")

---@class core.dirman.utils
module.public = {
    ---Resolve `$<workspace>/path/to/file` and return the real path
    ---@param path string # path
    ---@param raw_path boolean? # If true, returns resolved path, else, return with appended ".norg"
    ---@return string? # Resolved path. If path does not start with `$` or not absolute, adds relative from current file.
    expand_path = function(path, raw_path)
        -- Expand special chars like `$`
        local custom_workspace_path = path:match("^%$([^/\\]*)[/\\]")

        if custom_workspace_path then
            local dirman = modules.get_module("core.dirman")

            if not dirman then
                log.error(
                    "Unable to jump to link with custom workspace: `core.dirman` is not loaded. Please load the module in order to get workspace support."
                )
                return
            end

            -- If the user has given an empty workspace name (i.e. `$/myfile`)
            if custom_workspace_path:len() == 0 then
                path = dirman.get_current_workspace()[2] .. "/" .. path:sub(3)
            else -- If the user provided a workspace name (i.e. `$my-workspace/myfile`)
                local workspace_path = dirman.get_workspace(custom_workspace_path)

                if not workspace_path then
                    log.warn("Unable to expand path: workspace does not exist")
                    return
                end

                path = workspace_path .. "/" .. path:sub(custom_workspace_path:len() + 3)
            end
        else
            -- If the path isn't absolute (doesn't begin with `/` nor `~`) then prepend the current file's
            -- filehead in front of the path
            path = (vim.tbl_contains({ "/", "~" }, path:sub(1, 1)) and "" or (vim.fn.expand("%:p:h") .. "/")) .. path
        end

        return path .. (raw_path and "" or ".norg")
    end,
}

return module
