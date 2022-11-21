--[[
    File: Core-Presenter
    Title: Powerpoint-like for Neorg
    Summary: Neorg module to create gorgeous presentation slides.
    ---
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.presenter")
local api = vim.api

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
    local error_loading = false

    ---@type core.keybinds
    ---@diagnostic disable-next-line: unused-local
    local keybinds = module.required["core.keybinds"]

    if module.config.public.zen_mode == "truezen" then
        neorg.modules.load_module("core.integrations.truezen", module.name)
    elseif module.config.public.zen_mode == "zen-mode" then
        neorg.modules.load_module("core.integrations.zen_mode", module.name)
    else
        log.error("Unrecognized mode for 'zen_mode' option. Please check your presenter config")
        error_loading = true
    end

    if error_loading then
        return
    end

    keybinds.register_keybinds(module.name, { "next_page", "previous_page", "close" })
    -- Add neorgcmd capabilities
    module.required["core.neorgcmd"].add_commands_from_table({
        presenter = {
            args = 1,
            condition = "norg",
            subcommands = {
                start = { args = 0, name = "presenter.start" },
                close = { args = 0, name = "presenter.close" },
            },
        },
    })
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
        local buffer =
            module.required["core.ui"].create_norg_buffer("Norg Presenter", "nosplit", nil, { keybinds = false })

        api.nvim_buf_set_option(buffer, "modifiable", true)
        api.nvim_buf_set_lines(buffer, 0, -1, false, results[1])
        api.nvim_buf_call(buffer, function()
            vim.cmd("set scrolloff=999")
        end)

        api.nvim_buf_set_option(buffer, "modifiable", false)

        module.required["core.mode"].set_mode("presenter")
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

        api.nvim_buf_delete(module.private.buf, {})
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
