local module = neorg.modules.create("core.clipboard")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.load = function()
    vim.api.nvim_create_autocmd("TextYankPost", {
        callback = function(data)
            if vim.api.nvim_buf_get_option(data.buf, "filetype") ~= "norg" then
                return
            end

            local range = { vim.api.nvim_buf_get_mark(data.buf, "["), vim.api.nvim_buf_get_mark(data.buf, "]") }

            for i = range[1][1], range[2][1] do
                local node = module.required["core.integrations.treesitter"].get_first_node_on_line(data.buf, i)

                while node:parent() do
                    if module.private.callbacks[node:type()] then
                        local register = vim.fn.getreg(vim.v.event.regname)

                        vim.fn.setreg(
                            vim.v.event.regname,
                            neorg.lib.filter(module.private.callbacks[node:type()], function(_, cb)
                                return cb(node, register, { i, range[2] })
                            end)
                        )

                        return
                    end

                    node = node:parent()
                end
            end
        end,
    })
end

module.private = {
    callbacks = {},
}

module.public = {
    add_callback = function(node_type, func)
        module.private.callbacks[node_type] = module.private.callbacks[node_type] or {}
        table.insert(module.private.callbacks[node_type], func)
    end,
}

return module
