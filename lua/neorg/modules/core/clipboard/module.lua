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
            if vim.api.nvim_buf_get_option(data.buf, "filetype") ~= "norg" or vim.v.event.operator ~= "y" then
                return
            end

            local range = { vim.api.nvim_buf_get_mark(data.buf, "["), vim.api.nvim_buf_get_mark(data.buf, "]") }
            range[1][1] = range[1][1] - 1
            range[2][1] = range[2][1] - 1

            for i = range[1][1], range[2][1] do
                local node = module.required["core.integrations.treesitter"].get_first_node_on_line(data.buf, i)

                while node:parent() do
                    if module.private.callbacks[node:type()] then
                        local register = vim.fn.getreg(vim.v.register)

                        vim.fn.setreg(
                            vim.v.register,
                            neorg.lib.filter(module.private.callbacks[node:type()], function(_, callback)
                                if callback.strict and (range[1][1] < i or range[2][1] > node:end_()) then
                                    return
                                end

                                return callback.cb(
                                    node,
                                    vim.split(register, "\n", {
                                        plain = true,
                                        -- TODO: This causes problems in places
                                        -- where you actually want to copy
                                        -- newlines.
                                        trimempty = true,
                                    }),
                                    {
                                        start = range[1],
                                        ["end"] = range[2],
                                        current = { i, range[1][2] },
                                    }
                                )
                            end) or register,
                            "l"
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
    add_callback = function(node_type, func, strict)
        module.private.callbacks[node_type] = module.private.callbacks[node_type] or {}
        table.insert(module.private.callbacks[node_type], { cb = func, strict = strict })
    end,
}

return module
