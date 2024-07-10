--[[
    file: Core-Presenter
    title: Powerpoint in Neorg
    description: The presenter module creates slideshows out of notes or documents.
    summary: Neorg module to create gorgeous presentation slides.
    ---
The presenter module provides a special Neorg display that resembles an active slideshow
presentation.

To set it up, first be sure to set the `zen_mode` variable in the [configuration](#configuration).
Afterwards, run `:Neorg presenter start` on any Norg file. The presenter will split up your file
at each level 1 heading, and display each in a different slide.

NOTE: This module is due for a rewrite. All of its behaviour is not fully documented here as it will be
overwritten soon anyway.
--]]

local neorg = require("neorg.core")
local log, modules = neorg.log, neorg.modules

local module = modules.create("core.presenter")
local api = vim.api

module.setup = function()
    return {
        success = true,
        requires = {
            "core.queries.native",
            "core.integrations.treesitter",
            "core.ui",
        },
    }
end

module.load = function()
    local error_loading = false

    if module.config.public.zen_mode == "truezen" then
        modules.load_module("core.integrations.truezen")
    elseif module.config.public.zen_mode == "zen-mode" then
        modules.load_module("core.integrations.zen_mode")
    else
        log.error("Unrecognized mode for 'zen_mode' option. Please check your presenter config")
        error_loading = true
    end

    if error_loading then
        return
    end

    vim.keymap.set("", "<Plug>(neorg.presenter.next-page)", module.public.next_page)
    vim.keymap.set("", "<Plug>(neorg.presenter.previous-page)", module.public.previous_page)
    vim.keymap.set("", "<Plug>(neorg.presenter.close)", module.public.close)

    modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            presenter = {
                args = 1,
                condition = "norg",
                subcommands = {
                    start = { args = 0, name = "presenter.start" },
                    close = { args = 0, name = "presenter.close" },
                },
            },
        })
    end)
end

module.config.public = {
    -- Zen mode plugin to use. Currenly suppported:
    --
    -- - `zen-mode` - https://github.com/folke/zen-mode.nvim
    -- - `truezen` - https://github.com/Pocco81/TrueZen.nvim
    zen_mode = "",
}

module.private = {
    data = {},
    nodes = {},
    buf = nil,
    current_page = 1,

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

        if module.config.public.zen_mode == "truezen" and modules.is_module_loaded("core.integrations.truezen") then
            modules.get_module("core.integrations.truezen").toggle_ataraxis()
        elseif
            module.config.public.zen_mode == "zen-mode" and modules.is_module_loaded("core.integrations.zen_mode")
        then
            modules.get_module("core.integrations.zen_mode").toggle()
        end

        -- Generate views selection popup
        local buffer =
            module.required["core.ui"].create_norg_buffer("Norg Presenter", "nosplit", nil, { keybinds = false })

        api.nvim_buf_set_option(buffer, "modifiable", true)
        api.nvim_buf_set_lines(buffer, 0, -1, false, results[1])
        api.nvim_buf_call(buffer, function()
            vim.cmd("set scrolloff=999")
        end)

        api.nvim_buf_set_option(buffer, "modifiable", false)

        module.private.buf = buffer
        module.private.data = results
    end,

    next_page = function()
        if vim.tbl_isempty(module.private.data) or not module.private.buf then
            return
        end

        if vim.tbl_count(module.private.data) == module.private.current_page then
            api.nvim_buf_set_option(module.private.buf, "modifiable", true)
            api.nvim_buf_set_lines(module.private.buf, 0, -1, false, { "Press `next` again to close..." })
            api.nvim_buf_set_option(module.private.buf, "modifiable", false)
            module.private.current_page = module.private.current_page + 1
            return
        elseif vim.tbl_count(module.private.data) < module.private.current_page then
            module.public.close()
            return
        end

        module.private.current_page = module.private.current_page + 1

        api.nvim_buf_set_option(module.private.buf, "modifiable", true)
        api.nvim_buf_set_lines(module.private.buf, 0, -1, false, module.private.data[module.private.current_page])
        api.nvim_buf_set_option(module.private.buf, "modifiable", false)
    end,

    previous_page = function()
        if vim.tbl_isempty(module.private.data) or not module.private.buf then
            return
        end

        if module.private.current_page == 1 then
            return
        end

        module.private.current_page = module.private.current_page - 1

        api.nvim_buf_set_option(module.private.buf, "modifiable", true)
        api.nvim_buf_set_lines(module.private.buf, 0, -1, false, module.private.data[module.private.current_page])
        api.nvim_buf_set_option(module.private.buf, "modifiable", false)
    end,

    close = function()
        if not module.private.buf then
            return
        end

        if module.config.public.zen_mode == "truezen" and modules.is_module_loaded("core.integrations.truezen") then
            modules.get_module("core.integrations.truezen").toggle_ataraxis()
        elseif
            module.config.public.zen_mode == "zen-mode" and modules.is_module_loaded("core.integrations.zen_mode")
        then
            modules.get_module("core.integrations.zen_mode").toggle()
        end

        api.nvim_buf_delete(module.private.buf, {})
        module.private.data = {}
        module.private.current_page = 1
        module.private.buf = nil
        module.private.nodes = {}
    end,
}

module.on_event = function(event)
    if event.split_type[1] == "core.neorgcmd" then
        if event.split_type[2] == "presenter.start" then
            module.public.present()
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["presenter.start"] = true,
        ["presenter.close"] = true,
    },
}

return module
