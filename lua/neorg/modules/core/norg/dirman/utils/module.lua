--[[
    file: Dirman-Utils
    summary: A set of utilities for the @core.norg.dirman module.
--]]

local module = neorg.modules.create("core.norg.dirman.utils")

module.public = {
    expand_path = function(path)
        -- Expand special chars like `$`
        local custom_workspace_path = path:match("^%$([^/]*)/")

        if custom_workspace_path then
            local dirman = neorg.modules.get_module("core.norg.dirman")

            if not dirman then
                log.error(
                    "Unable to jump to link with custom workspace: `core.norg.dirman` is not loaded. Please load the module in order to get workspace support."
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

        return path .. ".norg"
    end,
}

return module
