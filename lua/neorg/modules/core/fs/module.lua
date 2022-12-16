--[[
    File: Filesystem
    Title: Module for Filesystem Operations
    Summary: A cross-platform set of utilities to traverse filesystems.
    ---
--]]

local module = neorg.modules.create("core.fs")

module.public = {
    directory_map = function(path, callback)
        for name, type in vim.fs.dir(path) do
            if type == "directory" then
                module.public.directory_map(table.concat({ path, "/", name }), callback)
            else
                callback(name, type, path)
            end
        end
    end,

    --- Recursively copies a directory from one path to another
    ---@param old_path string #The path to copy
    ---@param new_path string #The new location. This function will not
    --- succeed if the directory already exists.
    ---@return boolean #If true, the directory copying succeeded
    copy_directory = function(old_path, new_path)
        local file_permissions = tonumber("744", 8)
        local ok, err = vim.loop.fs_mkdir(new_path, file_permissions)

        if not ok then
            return ok, err
        end

        for name, type in vim.fs.dir(old_path) do
            if type == "file" then
                ok, err =
                    vim.loop.fs_copyfile(table.concat({ old_path, "/", name }), table.concat({ new_path, "/", name }))

                if not ok then
                    return ok, err
                end
            elseif type == "directory" and not vim.endswith(new_path, name) then
                ok, err = module.public.copy_directory(
                    table.concat({ old_path, "/", name }),
                    table.concat({ new_path, "/", name })
                )

                if not ok then
                    return ok, err
                end
            end
        end

        return true, nil
    end,
}

return module
