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
        },
    }
end

module.config.public = {
    sources = {
        news = {
            condition = function()
                -- TODO: Once we're done with the implementation we should
                -- make this bit check for the current Neorg version and the version
                -- our Neorg News is targeted towards. We should make sure to only display
                -- the Neorg news once, unless the user manually invokes :Neorg news
                return false
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
                        return { "Unable to read Neorg news, some error occurred :(" }
                    end

                    local content = vim.split(file:read("*a"), "\n", true)

                    io.close(file)

                    return content
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

module.neorg_post_load = function()
    vim.schedule(function()
        module.public.display_news(module.public.parse_source("news"))
    end)
end

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
                vim.list_extend(parsed_text, item())
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

        return vim.api.nvim_open_win(buf, true, parsed_source.config)
    end,

    parse_all_sources = function() end,
}

return module
