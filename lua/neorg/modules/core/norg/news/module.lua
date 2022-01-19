--[[
    File: Displaying-News
    Title: Seeing The Latest Neorg News at Your Fingertips
    Summary: Handles the displaying of Neorg news and other forms of media in a popup.
    ---
--]]

local module = neorg.modules.create("core.norg.news")

module.setup = function()
    return {
        requires = {
            "core.ui",
            "core.storage",
            "core.neorgcmd",
        },
    }
end

module.config.public = {
    check_news = true,
}

module.load = function()
    -- Get the cached Neorg version
    local cached_neorg_version = module.required["core.storage"].retrieve(module.name).news_state

    if not cached_neorg_version then
        module.required["core.storage"].store(module.name, {
            news_state = neorg.configuration.version,
        })

        return
    end

    local path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/data/"

    vim.loop.fs_scandir(path, function(err, data)
        local paths = {}

        assert(not err, "Unable to open Neorg news directory at '" .. path .. "'!")

        local entry = vim.loop.fs_scandir_next(data)

        while entry do
            if vim.endswith(entry, ".norg") then
                paths[entry:sub(1, -(string.len(".norg") + 1))] = path .. entry
            end

            entry = vim.loop.fs_scandir_next(data)
        end

        local function compare_versions(ver1, ver2)
            -- Here we assume that the versions aren't malformed
            ver1, ver2 = neorg.utils.parse_version_string(ver1), neorg.utils.parse_version_string(ver2)

            return (ver1.major > ver2.major or ver1.minor > ver2.minor or ver1.patch > ver2.patch)
                and (ver1.major >= ver2.major and ver1.minor >= ver2.minor and ver1.patch >= ver2.patch)
        end

        for version, filepath in pairs(paths) do
            if compare_versions(version, neorg.configuration.version) then
                module.private.news[version] = filepath
                --[[ vim.loop.fs_open(path, "r", 438, function(err, fd)
                    assert(not err, "Unable to open neorg file: " )
                end) ]]
            end
        end
    end)
end

module.private = {
    news = {},
}

module.public = {
    neorg_commands = {},
}

return module
