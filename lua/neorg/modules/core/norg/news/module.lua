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
        },
    }
end

module.config.public = {
    sources = {
        news = {
            condition = function()
                local news = module.required["core.storage"].retrieve(module.name)

                local parsed_neorg_version, parsed_news_state =
                    neorg.utils.parse_version_string(neorg.configuration.version),
                    neorg.utils.parse_version_string(news.news_state)

                if
                    not parsed_neorg_version
                    or not parsed_news_state
                    or (
                        (
                            parsed_news_state.major <= parsed_neorg_version.major
                            and parsed_news_state.minor <= parsed_neorg_version.minor
                            and parsed_news_state.patch <= parsed_neorg_version.patch
                        )
                        and (
                            parsed_news_state.major < parsed_neorg_version.major
                            or parsed_news_state.minor < parsed_neorg_version.minor
                            or parsed_news_state.patch < parsed_neorg_version.patch
                        )
                    )
                then
                    news.news_state = neorg.configuration.version
                    module.required["core.storage"].store(module.name, news)
                    return true
                end
            end,
            config = {
                window = {
                    relative = "win",
                    width = 100,
                    height = 40,
                    border = "single",
                    style = "minimal",
                },
                custom = {
                    center_x = true,
                    center_y = true,
                },
            },
            template = {
                function()
                    local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")

                    local file = io.open(source .. "/news.norg", "r")

                    if not file then
                        return {
                            "Unable to read Neorg news, it seems the `news.norg` file doesn't exist?",
                            "To exit this window press either `<Esc>` or `q`.",
                        }
                    end

                    local content_as_whole_str = file:read("*a")
                    local content = vim.split(content_as_whole_str, "\n", true)

                    io.close(file)

                    return content, not content_as_whole_str:match("display:%s+true\n")
                end,
            },
        },
        --[[ newcomer = {
            condition = function()
                return not file_exists(vim.fn.stdpath("data") .. "/neorg/new")
            end,
            config = {
                window = {
                    relative = "win",
                    style = "minimal",
                    border = "single",
                    width = 100,
                    height = 40,
                },
                custom = {
                    center_x = true,
                    center_y = true,
                }
            },
            template = {
                "* _Welcome to Neorg!_",
                "  It seems like this is your first time booting Neorg on this machine.",
                "  If you already know about the juiciness that you can expect from Neorg you can",
                "  press `q` or `<Esc>` to quit this dialog. If you don't we recommend reading this!",
                "",
                "* *Quickstart*",
                "  There's quite a bit to the project, so let's get you up and running ASAP.",
                "",
                "** The File Format",
                "   Before you start doing any serious work it's important to not only become familiar with",
                "   but also get to /understand/ the Neorg format. You can execute `:help neorg`",
                "   to get a nice rundown of how our syntax looks and what makes it special.",
                "",
                "** Video Tutorials",
            },
        }, ]]
    },
}

module.public = {
    parse_source = function(name)
        local source = module.config.public.sources[name]

        if not source or not source.condition or not source.condition() then
            return
        end

        source = vim.tbl_deep_extend("keep", source, {
            condition = false,
            config = {
                window = {},
                custom = {},
            },
            template = {},
        })

        local parsed_text = {}

        for _, item in ipairs(source.template) do
            local item_type = type(item)

            if item_type == "function" then
                local ret, halt = item()

                if halt then
                    return
                end

                vim.list_extend(parsed_text, ret)
            elseif item_type == "string" then
                table.insert(parsed_text, item)
            end
        end

        return {
            text = parsed_text,
            config = module.required["core.ui"].apply_custom_options(source.config.custom, source.config.window),
        }
    end,

    display_news = function(parsed_source)
        if not parsed_source then
            return
        end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, "filetype", "norg")
        vim.api.nvim_buf_set_name(buf, "popup.norg")
        vim.api.nvim_buf_set_lines(buf, 0, -1, true, parsed_source.text)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)

        vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":bdelete<CR>", { silent = true, noremap = true })
        vim.api.nvim_buf_set_keymap(buf, "n", "q", ":bdelete<CR>", { silent = true, noremap = true })

        return vim.api.nvim_open_win(buf, true, parsed_source.config), buf
    end,

    parse_all_sources = function() end,
}

module.on_event = function(event)
    if event.type == "core.started" then
        local timer = vim.loop.new_timer()
        timer:start(
            1000,
            0,
            vim.schedule_wrap(function()
                module.public.display_news(module.public.parse_source("news"))
            end)
        )
    end
end

module.events.subscribed = {
    core = {
        started = true,
    },
}

return module
