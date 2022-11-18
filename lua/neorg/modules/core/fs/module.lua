--[[
    File: Filesystem
    Title: Module for Filesystem Operations
    Summary: A cross-platform set of utilities to traverse filesystems.
    ---
--]]

local module = neorg.modules.create("core.fs")

module.public = {
    --- Recursively copies a directory from one path to another
    ---@param old_path string #The path to copy
    ---@param new_path string #The new location. This function will not
    --- succeed if the directory already exists.
    ---@return boolean #If true, the directory copying succeeded
    copy_directory = function(old_path, new_path)
        local file_permissions = tonumber("744", 8)
        local ok = vim.loop.fs_mkdir(new_path, file_permissions)

        if not ok then
            log.error(("Unable to create backup directory '%s'! Perhaps the directory already exists and/or isn't empty?"):format(new_path))
            return false
        end

        local success = true

        for name, type in vim.fs.dir(old_path) do
            if type == "file" then
                success = (vim.loop.fs_copyfile(table.concat({ old_path, "/", name }), table.concat({ new_path, "/", name })) ~= nil)
            elseif type == "directory" and not vim.endswith(new_path, name) then
                success = module.public.copy_directory(table.concat({ old_path, "/", name }), table.concat({ new_path, "/", name }))
            end
        end

        return success
    end,
}

return module
