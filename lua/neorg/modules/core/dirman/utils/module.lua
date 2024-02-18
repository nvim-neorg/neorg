--[[
    file: Dirman-Utils
    summary: A set of utilities for the `core.dirman` module.
    internal: true
    ---
This internal submodule implements some basic utility functions for [`core.dirman`](@core.dirman).
Currently the only exposed API function is `expand_path`, which takes a path like `$name/my/location` and
converts `$name` into the full path of the workspace called `name`.
--]]

local Path = require("pathlib")

local neorg = require("neorg.core")
local log, modules = neorg.log, neorg.modules

local module = neorg.modules.create("core.dirman.utils")

---@class core.dirman.utils
module.public = {
    ---Resolve `$<workspace>/path/to/file` and return the real path
    ---@param path string|PathlibPath # path
    ---@param raw_path boolean? # If true, returns resolved path, otherwise, returns resolved path and append ".norg"
    ---@return PathlibPath? # Resolved path. If path does not start with `$` or not absolute, adds relative from current file.
    expand_pathlib = function(path, raw_path)
        local filepath = Path(path)
        -- Expand special chars like `$`
        local custom_workspace_path = filepath:match("^%$([^/\\]*)[/\\]")
        if custom_workspace_path then
            ---@type core.dirman
            local dirman = modules.get_module("core.dirman")
            if not dirman then
                log.error(table.concat({
                    "Unable to jump to link with custom workspace: `core.dirman` is not loaded.",
                    "Please load the module in order to get workspace support.",
                }, " "))
                return
            end
            -- If the user has given an empty workspace name (i.e. `$/myfile`)
            if custom_workspace_path:len() == 0 then
                filepath = dirman.get_current_workspace()[2] / filepath:relative_to(Path("$"))
            else -- If the user provided a workspace name (i.e. `$my-workspace/myfile`)
                local workspace = dirman.get_workspace(custom_workspace_path)
                if not workspace then
                    local msg = "Unable to expand path: workspace '%s' does not exist"
                    log.warn(string.format(msg, custom_workspace_path))
                    return
                end
                filepath = workspace / filepath:relative_to(Path("$" .. custom_workspace_path))
            end
        elseif filepath:is_relative() then
            local this_file = Path(vim.fn.expand("%:p")):absolute()
            filepath = this_file:parent_assert() / filepath
        else
            filepath = filepath:absolute()
        end
        -- requested to expand norg file
        if not raw_path then
            if type(path) == "string" and (path:sub(#path) == "/" or path:sub(#path) == "\\") then
                -- if path ends with `/`, it is an invalid request!
                log.error(table.concat({
                    "Norg file location cannot point to a directory.",
                    string.format("Current link points to '%s'", path),
                    "which ends with a `/`.",
                }, " "))
                return
            end
            filepath = filepath:add_suffix(".norg")
        end
        return filepath
    end,
    ---Resolve `$<workspace>/path/to/file` and return the real path
    -- NOTE: Use `expand_pathlib` which returns a PathlibPath object instead.
    ---
    ---\@deprecate Use `expand_pathlib` which returns a PathlibPath object instead. TODO: deprecate this <2024-03-27>
    ---@param path string|PathlibPath # path
    ---@param raw_path boolean? # If true, returns resolved path, otherwise, returns resolved path and append ".norg"
    ---@return string? # Resolved path. If path does not start with `$` or not absolute, adds relative from current file.
    expand_path = function(path, raw_path)
        local res = module.public.expand_pathlib(path, raw_path)
        return res and res:tostring() or nil
    end,

    ---transform a path to a path that's relative to the workspace. Cleans up "/folder/.."
    ---@param path string path relative to `dir` which is converted to a workspace path
    ---@return string ws relative link like `$/path/to/some/file`
    to_workspace_relative = function(path)
        local dirman = modules.get_module("core.dirman")

        if not dirman then
            log.error(
                "Unable to jump to link with custom workspace: `core.dirman` is not loaded. Please load the module in order to get workspace support."
            )
            return ""
        end

        local workspace_dir = dirman.get_current_workspace()[2]
        local ws_path = "$" .. string.gsub(path, "^" .. workspace_dir, "")
        ws_path = string.gsub(ws_path, "/[^/]+/%.%./", "/")
        return ws_path
    end,
}

return module
