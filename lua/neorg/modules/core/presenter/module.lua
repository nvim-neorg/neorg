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

    module.required["core.keybinds"].register_keybinds(module.name, { "next_page", "previous_page", "close" })
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

---@class core.presenter.config
module.config.public = {}

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
                query = { "first", "document_content" },
                subtree = {
                    {
                        query = { "all", "heading1" },
                        recursive = true,
                    },
                },
            },
        }
        local results = queries.query_nodes_from_buf(tree, 0)
        module.private.nodes = results
        results = queries.extract_nodes(results, { all_lines = true })

        -- Generate views selection popup
        local buffer = module.required["core.ui"].create_norg_buffer("Norg Presenter", "nosplit", nil, false)
        vim.api.nvim_buf_call(buffer, function()
            vim.cmd("set scrolloff=999")
        end)

        vim.api.nvim_buf_set_option(buffer, "modifiable", true)
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, results[1])
        vim.api.nvim_buf_call(buffer, function()
            vim.cmd("set scrolloff=999")
        end)
        vim.api.nvim_buf_set_option(buffer, "modifiable", false)

        module.required["core.mode"].set_mode("presenter")

        module.private.buf = buffer
        module.private.data = results
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
    end,

    close = function()
        if not module.private.buf then
            return
        end

        -- Go back to previous mode
        local previous_mode = module.required["core.mode"].get_previous_mode()
        module.required["core.mode"].set_mode(previous_mode)

        vim.api.nvim_buf_delete(module.private.buf, {})
        module.private.data = {}
        module.private.current_page = 1
        module.private.buf = nil
        module.private.nodes = {}
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
