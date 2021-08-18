--[[
    A UI module to allow the user to press different keys to select different actions
--]]

return function(module)
    return {

        create_selection = function(name, config, callback)
            vim.validate({
                name = { name, "string" },
                config = { config, "table" },
                callback = { callback, "function" },
            })

            local buf = module.public.create_split("selection/" .. name, config.buffer_options)

            local function display_values(flags)
                vim.api.nvim_buf_clear_namespace(buf, module.private.namespace, 0, -1)

                vim.api.nvim_buf_set_lines(
                    buf,
                    0,
                    #vim.tbl_keys(flags) + 1,
                    false,
                    vim.split(("\n"):rep(#vim.tbl_keys(flags) + 1), "\n", true)
                )

                local text_for_current = (function()
                    local result = {
                        { { name .. ":", "TSAnnotation" } },
                        { { " ", "Normal" } },
                    }

                    for keybind, value in pairs(flags) do
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
            end

            display_values(config.flags)

            local location, result = config.flags, {}

            -- WARNING: Idk why but for some reason this gets executed before the buffer is displayed, what??
            while location do
                local input = vim.fn.getcharstr()

                if location[input] then
                    table.insert(result, input)

                    if type(location[input]) == "string" then
                        callback(result)
                        break
                    else
                        if not location[input].flags then
                            log.error(
                                'Malformed input provided to create_selection: expected a "flags" variable in subtable'
                            )
                            break
                        end

                        location = location[input].flags
                        display_values(location)
                    end
                end
            end

            vim.api.nvim_buf_delete(buf, { force = true })
        end,

        -- Creates a split and returns the buffer ID contained within the split
        create_split = function(name, config)
            vim.validate({
                name = { name, "string" },
                config = { config, "table", true },
            })

            vim.cmd("below new")

            local buf = vim.api.nvim_get_current_buf()

            local default_options = {
                modified = false,
                buflisted = false,
                swapfile = false,
                bufhidden = "hide",
                buftype = "nofile",
            }

            vim.api.nvim_buf_set_name(buf, "neorg://" .. name)
            module.public.apply_buffer_options(buf, vim.tbl_extend("keep", config or {}, default_options))

            return buf
        end,
    }
end
