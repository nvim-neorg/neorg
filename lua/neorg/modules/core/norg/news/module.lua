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
    sources = {
        breaking_changes = {
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
                    border = "single",
                    style = "minimal",
                },
                custom = {
                    center_x = true,
                    center_y = true,
                },

                message = "There have been some breaking changes!",
                check_at_startup = true,
            },
            template = {
                function()
                    local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")

                    local file = io.open(source .. "/news.norg", "r")

                    if not file then
                        return {
                            "Unable to read Neorg news, it seems the `news.norg` file doesn't exist?",
                            "To exit this window press either `<Esc>` or `q`.",
                            "You can run `:Neorg news breaking_changes` at any time to try again.",
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

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            news = neorg.lib.to_keys(vim.tbl_keys(module.config.public.sources), {}),
        },

        data = {
            news = {
                max_args = 1,
                name = "news",
            },
        },
    })

    local christmas = module.required["core.storage"].retrieve("christmas")

    if type(christmas) == "table" and vim.tbl_isempty(christmas) then
        vim.schedule(function()
            vim.notify(
                [[
Hey! If you're reading this that means our code works!

Just wanted to wish you all a merry christmas and wonderful holidays.
Thank you ever so much for sticking with us and providing us with a genuine
future for this project through your suggestions and feedback.

We'll be away for the next two or three days for christmas, so we're sorry if
we don't respond to any issues, discussions and/or PRs.

In the meantime we hope you don't mind the very slow concealer, we'll
be heavily improving the performance of that thing once we get back. In
the meantime you may wanna disable that thing if it gets too bad lol.

Thank you so much for your everlasting love and support, see you on the flipside!
The Neorg Team

See :messages for full output]],
                vim.log.levels.WARN
            )
        end)

        module.required["core.storage"].store("christmas", true)
    end
end

module.public = {
    parse_source = function(name, force)
        local source = module.config.public.sources[name]

        if not source or ((not source.condition or not source.condition()) and not force) then
            return
        end

        source = vim.tbl_deep_extend("keep", source, {
            condition = false,
            config = {
                window = {
                    width = vim.opt_local.columns:get(),
                    height = vim.opt_local.lines:get(),
                },
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
            message = source.config.message,
            check_at_startup = source.config.check_at_startup,
        }
    end,

    display_news = function(parsed_source)
        if not parsed_source then
            return
        end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, "filetype", "norg")
        vim.api.nvim_buf_set_name(buf, "popup.norg")

        vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":bdelete<CR>", { silent = true, noremap = true })
        vim.api.nvim_buf_set_keymap(buf, "n", "q", ":bdelete<CR>", { silent = true, noremap = true })

        local center = {}
        local should_center = false

        for i, line in ipairs(parsed_source.text) do
            if line == "<" then
                table.remove(parsed_source.text, i)
                should_center = true
            elseif line == ">" then
                table.remove(parsed_source.text, i)
                should_center = false
            end

            if should_center then
                table.insert(center, i)
            end
        end

        local win = vim.api.nvim_open_win(buf, true, parsed_source.config)

        vim.api.nvim_buf_set_lines(buf, 0, -1, true, parsed_source.text)
        vim.api.nvim_buf_set_option(buf, "textwidth", parsed_source.config.width)

        for _, i in ipairs(center) do
            vim.api.nvim_win_set_cursor(win, { i, 0 })
            vim.cmd("center")
        end

        vim.api.nvim_buf_set_option(buf, "modifiable", false)
        vim.api.nvim_win_set_cursor(win, { 1, 0 })

        return win, buf
    end,

    parse_all_sources = function(is_startup)
        local sources = {}

        for name, source in pairs(module.config.public.sources) do
            if is_startup and not source.config.check_at_startup then
                goto continue
            end

            local parsed_source = module.public.parse_source(name)

            if parsed_source then
                sources[name] = parsed_source
            end

            ::continue::
        end

        return sources
    end,

    -- TODO: Add functions that dynamically add sources
}

module.on_event = function(event)
    if event.type == "core.started" then
        local timer = vim.loop.new_timer()
        timer:start(
            1000,
            0,
            vim.schedule_wrap(function()
                for name, source in pairs(module.public.parse_all_sources(true)) do
                    if source.check_at_startup then
                        vim.notify(
                            source.message .. " - see ':Neorg news " .. name .. "' for details.",
                            vim.log.levels.WARN
                        )
                    end
                end
            end)
        )
    elseif event.type == "core.neorgcmd.events.news" then
        if vim.tbl_isempty(event.content) then
            vim.notify("Displaying all available Neorg news:")
            for name, source in pairs(module.public.parse_all_sources()) do
                vim.notify(source.message .. " - see ':Neorg news " .. name .. "' for details.", vim.log.levels.WARN)
            end
            vim.notify("Execute :messages or press `g<` for more info.")
            return
        end

        local source = module.public.parse_source(event.content[1], true)

        if not source then
            vim.notify('No news available for "' .. event.content[1] .. '"')
            return
        end

        module.public.display_news(source)
    end
end

module.events.subscribed = {
    core = {
        started = true,
    },

    ["core.neorgcmd"] = {
        news = true,
    },
}

return module
