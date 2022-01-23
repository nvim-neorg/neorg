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
                module.private.new_news[version] = filepath
            else
                module.private.old_news[version] = filepath
            end
        end

        local lib = neorg.lib

        local old_keys, new_keys = vim.tbl_keys(module.private.old_news), vim.tbl_keys(module.private.new_news)

        local commands_table = {
            definitions = {
                news = {
                    new = lib.to_keys(new_keys),
                    old = lib.to_keys(old_keys),
                    all = {},
                },
            },
            data = {
                news = {
                    args = 1,
                    subcommands = {
                        old = {
                            args = 1,
                            subcommands = lib.construct(old_keys, function(key)
                                return {
                                    args = 0,
                                    name = "news.old." .. key,
                                }
                            end),
                        },
                        new = {
                            name = "news.new",
                            max_args = 1,
                            subcommands = lib.construct(new_keys, function(key)
                                return {
                                    args = 0,
                                    name = "news.new." .. key,
                                }
                            end),
                        },
                        all = {
                            name = "news.all",
                            args = 0,
                        },
                    },
                },
            },
        }

        module.required["core.neorgcmd"].add_commands_from_table(commands_table)

        module.events.subscribed = {
            ["core.neorgcmd"] = lib.to_keys(lib.extract(commands_table.data.news.subcommands, "name"), true),
        }

        if not vim.tbl_isempty(module.private.new_news) then
            vim.schedule(function()
                vim.notify(string.format(
                    [[
There's some new Neorg news for you!"

New news for versions: %s

Run `:Neorg news new <version>` to see the latest news for that specific version.
To view news for all new versions run `:Neorg news new` without arguments.
                ]],
                    table.concat(new_keys, ", ")
                ))
            end)
        end
    end)
end

module.public = {
    get_content = function(versions)
        local content = {}

        for _, location in pairs(versions) do
            -- Using libuv is totally overkill here
            local file = io.open(location, "r")

            if not file then
                file:close()
                goto continue
            end

            vim.list_extend(
                content,
                vim.split(file:read("*a"), "\n", {
                    plain = true,
                })
            )

            ::continue::
        end

        return content
    end,

    create_display = function(content)
        local buf = vim.api.nvim_create_buf(false, true)

        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
        vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
        vim.api.nvim_buf_set_option(buf, "filetype", "norg")
        vim.api.nvim_buf_set_name(buf, "news.norg")

        -- Taken from nvim-lsp-installer at https://github.com/williamboman/nvim-lsp-installer/blob/main/lua/nvim-lsp-installer/ui/display.lua#L143-L157
        -- Big shoutout! I couldn't figure this out myself.
        local win_height = vim.o.lines - vim.o.cmdheight - 2 -- Add margin for status and buffer line
        local win_width = vim.o.columns

        local window_opts = {
            relative = "editor",
            height = math.floor(win_height * 0.9),
            width = math.floor(win_width * 0.8),
            style = "minimal",
            border = "rounded",
        }

        window_opts.row = math.floor((win_height - window_opts.height) / 2)
        window_opts.col = math.floor((win_width - window_opts.width) / 2)

        return vim.api.nvim_open_win(buf, true, window_opts)
    end,
}

module.private = {
    old_news = {},
    new_news = {},
}

module.on_event = function(event)
    if event.split_type[2] == "news.all" then
        module.public.create_display(
            module.public.get_content(vim.tbl_extend("error", module.private.old_news, module.private.new_news))
        )
    end
end

return module
