--[[
    File: Core-Presenter
    Title: Powerpoint-like for Neorg
    Summary: Neorg module to create gorgeous presentation slides.
    ---
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.presenter")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.queries.native",
            "core.integrations.treesitter",
            "core.ui",
            "core.mode",
            "core.keybinds",
            "core.neorgcmd",
        },
    }
end

module.load = function()
    ---@type core.keybinds
    ---@diagnostic disable-next-line: unused-local
    local keybinds = module.required["core.keybinds"]

    if module.config.public.zen_mode == "truezen" then
        neorg.modules.load_module("core.integrations.truezen", module.name)
    elseif module.config.public.zen_mode == "zen-mode" then
        neorg.modules.load_module("core.integrations.zen_mode", module.name)
    end

    keybinds.register_keybinds(module.name, { "next_page", "previous_page", "close" })
    -- Add neorgcmd capabilities
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            presenter = {
                start = {},
                close = {},
            },
        },
        data = {
            presenter = {
                args = 1,
                subcommands = {
                    start = { args = 0, name = "presenter.start" },
                    close = { args = 0, name = "presenter.close" },
                },
            },
        },
    })
end

module.config.public = {
    -- Zen mode plugin to use. Currently supported:
    -- `zen-mode` (https://github.com/folke/zen-mode.nvim)
    -- `truezen` (https://github.com/Pocco81/TrueZen.nvim)
    zen_mode = "",

    slide_count = {
        -- Whether to show slide count or not.
        enable = true,

        -- The format of the slide count if it's enabled.
        -- This can be a string where `%d` will get replaced with current slide number and total line count.
        -- If there is only one `%d` only the number of the current slide will be displayed.
        count_format = "[%d/%d]",

        -- Where to place the slide count. Currently supported:
        -- `top`: Places the count in the top right corner.
        -- `bottom`: Places the count in the bottom right corner.
        position = "top",

        -- The highlight group to use to highlight the slide count.
        highlight = "String",
    },
}

module.private = {
    data = {},
    nodes = {},
    buf = nil,
    current_page = 1,
    ns = nil,
    display_slide_count = function()
        if module.config.public.slide_count.enable then
            local text = string.format(
                module.config.public.slide_count.count_format,
                module.private.current_page,
                #module.private.data
            )
            if module.config.public.slide_count.position == "top" then
                vim.api.nvim_buf_set_extmark(module.private.buf, module.private.ns, 0, 1, {
                    virt_text = {
                        {
                            text,
                            module.config.public.slide_count.highlight,
                        },
                    },
                    virt_text_pos = "right_align",
                })
            elseif module.config.public.slide_count.position == "bottom" then
                local line = #module.private.data[module.private.current_page] - 1
                -- TODO: Move to it's own line (`virt_lines`) -> right align text on virtual line
                vim.api.nvim_buf_set_extmark(module.private.buf, module.private.ns, line, 1, {
                    virt_text = {
                        {
                            text,
                            module.config.public.slide_count.highlight,
                        },
                    },
                    virt_text_pos = "right_align",
                })
            end
        else
            log.error("Invalid position for line count.")
        end
    end,
}

---@class core.presenter
module.public = {
    version = "0.0.8",
    present = function()
        if module.private.buf then
            log.warn("Presentation already started")
            return
        end
        ---@type core.queries.native
        local queries = module.required["core.queries.native"]

        module.private.ns = vim.api.nvim_create_namespace("neorg_presenter")

        -- Get current file and check if it's a norg one
        local uri = vim.uri_from_bufnr(0)
        local fname = vim.uri_to_fname(uri)

        if string.sub(fname, -5, -1) ~= ".norg" then
            log.error("Not on a norg file")
            return
        end

        local tree = {
            {
                query = { "all", "heading1" },
                recursive = true,
            },
        }
        -- Free the text in memory after reading nodes
        queries.delete_content(0)

        local results = queries.query_nodes_from_buf(tree, 0)

        if vim.tbl_isempty(results) then
            log.warn("Could not generate the presenter mode (no heading1 present on this file)")
            return
        end

        module.private.nodes = results
        results = queries.extract_nodes(results, { all_lines = true })

        results = module.private.remove_blanklines(results)

        -- This is a temporary fix because querying the heading1 nodes seems to query the next heading1 node too !
        for _, res in pairs(results) do
            if vim.startswith(res[#res], "* ") then
                res[#res] = nil
            end
        end

        if
            module.config.public.zen_mode == "truezen" and neorg.modules.is_module_loaded("core.integrations.truezen")
        then
            neorg.modules.get_module("core.integrations.truezen").toggle_ataraxis()
        elseif
            module.config.public.zen_mode == "zen-mode" and neorg.modules.is_module_loaded("core.integrations.zen_mode")
        then
            neorg.modules.get_module("core.integrations.zen_mode").toggle()
        end

        -- Generate views selection popup
        local buffer = module.required["core.ui"].create_norg_buffer(
            "Norg Presenter",
            "nosplit",
            nil,
            { keybinds = false }
        )

        vim.api.nvim_buf_set_option(buffer, "modifiable", true)
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, results[1])
        vim.api.nvim_buf_call(buffer, function()
            vim.cmd("set scrolloff=999")
        end)

        vim.api.nvim_buf_set_option(buffer, "modifiable", false)

        module.required["core.mode"].set_mode("presenter")
        module.private.buf = buffer
        module.private.data = results
        module.private.display_slide_count()
    end,

    next_page = function()
        if vim.tbl_isempty(module.private.data) or not module.private.buf then
            return
        end

        if vim.tbl_count(module.private.data) == module.private.current_page then
            vim.api.nvim_buf_set_option(module.private.buf, "modifiable", true)
            vim.api.nvim_buf_set_lines(module.private.buf, 0, -1, false, { "Press `next` again to close..." })
            vim.api.nvim_buf_set_option(module.private.buf, "modifiable", false)
            module.private.current_page = module.private.current_page + 1
            return
        elseif vim.tbl_count(module.private.data) < module.private.current_page then
            module.public.close()
            return
        end

        module.private.current_page = module.private.current_page + 1

        vim.api.nvim_buf_set_option(module.private.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(module.private.buf, 0, -1, false, module.private.data[module.private.current_page])
        vim.api.nvim_buf_set_option(module.private.buf, "modifiable", false)
        module.private.display_slide_count()
    end,

    previous_page = function()
        if vim.tbl_isempty(module.private.data) or not module.private.buf then
            return
        end

        if module.private.current_page == 1 then
            return
        end

        module.private.current_page = module.private.current_page - 1

        vim.api.nvim_buf_set_option(module.private.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(module.private.buf, 0, -1, false, module.private.data[module.private.current_page])
        vim.api.nvim_buf_set_option(module.private.buf, "modifiable", false)
        module.private.display_slide_count()
    end,

    close = function()
        if not module.private.buf then
            return
        end

        -- Go back to previous mode
        local previous_mode = module.required["core.mode"].get_previous_mode()
        module.required["core.mode"].set_mode(previous_mode)

        if
            module.config.public.zen_mode == "truezen" and neorg.modules.is_module_loaded("core.integrations.truezen")
        then
            neorg.modules.get_module("core.integrations.truezen").toggle_ataraxis()
        elseif
            module.config.public.zen_mode == "zen-mode" and neorg.modules.is_module_loaded("core.integrations.zen_mode")
        then
            neorg.modules.get_module("core.integrations.zen_mode").toggle()
        end

        vim.api.nvim_buf_delete(module.private.buf, {})
        module.private.data = {}
        module.private.current_page = 1
        module.private.buf = nil
        module.private.nodes = {}
    end,
}

module.private = {
    remove_blanklines = function(t)
        local copy = t
        for k, _t in pairs(copy) do
            -- Stops at the first non-blankline text
            local found_non_blankline = false

            for i = #_t, 1, -1 do
                if not found_non_blankline then
                    local value = _t[i]
                    value = string.gsub(value, "%s*", "")
                    if value == "" then
                        table.remove(copy[k], i)
                    else
                        found_non_blankline = true
                    end
                end
            end
        end
        return copy
    end,
}

module.on_event = function(event)
    if vim.tbl_contains({ "core.neorgcmd", "core.keybinds" }, event.split_type[1]) then
        if vim.tbl_contains({ "presenter.start" }, event.split_type[2]) then
            module.public.present()
        elseif vim.tbl_contains({ "presenter.close", "core.presenter.close" }, event.split_type[2]) then
            module.public.close()
        elseif vim.tbl_contains({ "core.presenter.previous_page" }, event.split_type[2]) then
            module.public.previous_page()
        elseif vim.tbl_contains({ "core.presenter.next_page" }, event.split_type[2]) then
            module.public.next_page()
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["presenter.start"] = true,
        ["presenter.close"] = true,
    },
    ["core.keybinds"] = {
        ["core.presenter.previous_page"] = true,
        ["core.presenter.next_page"] = true,
        ["core.presenter.close"] = true,
    },
}

return module
