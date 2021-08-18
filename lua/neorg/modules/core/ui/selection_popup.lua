--[[
    A UI module to allow the user to press different keys to select different actions
--]]

return function(module)
    return {

        create_selection = function(name, config)
            vim.validate({
                name = { name, "string" },
                config = { config, "table" },
            })

            local buf = module.public.create_split("selection/" .. name, config.buffer_options, function(buf)
                -- TODO: refactor out the vim.tbl_keys
                vim.api.nvim_buf_set_lines(
                    buf,
                    0,
                    #vim.tbl_keys(config.flags) + 1,
                    false,
                    vim.split(("\n"):rep(#vim.tbl_keys(config.flags) + 1), "\n", true)
                )
            end)

            if buf == -1 then
                log.error("Unable to create selection, buffer with name", name, "not found")
                return
            end

            local text_for_current = (function()
                local result = {
                    { { name .. ":", "TSAnnotation" } },
                    { { " ", "Normal" } },
                }

                for keybind, value in pairs(config.flags) do
                    local keybind_element = {}

                    table.insert(keybind_element, { keybind, "TSType" })
                    table.insert(keybind_element, { " -> ", "Normal" })

                    if type(value) == "table" then
                        table.insert(keybind_element, { value.name or "no description", "TSMath" })
                    elseif type(value) == "string" then
                        table.insert(keybind_element, { value, "TSMath" })
                    else
                        table.insert(keybind_element, { tostring(value), "TSMath" })
                    end

                    table.insert(result, keybind_element)
                end

                return result
            end)()

            for i, virt_text in ipairs(text_for_current) do
                vim.api.nvim_buf_set_extmark(buf, module.private.namespace, i - 1, 0, {
                    virt_text = virt_text,
                    virt_text_pos = "overlay",
                })
            end
        end,

        -- Creates a split and returns the buffer ID contained within the split
        create_split = function(name, config, callback)
            if vim.fn.bufexists("neorg://" .. name) == 1 then
                return vim.fn.bufnr("neorg://" .. name)
            end

            vim.validate({
                name = { name, "string" },
                config = { config, "table", true },
                callback = { callback, "function", true },
            })

            vim.cmd("split neorg://" .. name)

            local buf = vim.fn.bufnr("neorg://" .. name)

            if buf == -1 then
                return buf
            end

            local default_options = {
                modified = false,
                modifiable = false,
                buflisted = false,
            }

            if callback then
                callback(buf)
            end

            vim.api.nvim_win_set_buf(0, buf)

            module.public.apply_buffer_options(buf, vim.tbl_extend("keep", config or {}, default_options))

            return buf
        end,
    }
end
