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

            -- Create a new horizontal split, we'll be placing our UI elements here
            local buf = module.public.create_split("selection/" .. name, config.buffer_options)

            ---Displays all possible keys the user can press
            ---@param title string the title of the keybinds
            ---@param flags table the list of flags to display
            local function display_values(title, flags)
                -- Remove any already present extmarks
                vim.api.nvim_buf_clear_namespace(buf, module.private.namespace, 0, -1)

                -- Apply the correct amount of lines to the buffer so it doesn't look weird
                vim.api.nvim_buf_set_lines(
                    buf,
                    0,
                    -1,
                    false,
                    vim.split(("\n"):rep(#vim.tbl_keys(flags) + 1), "\n", true)
                )

                -- Convert our table format into one that Neovim's extmarks API can understand
                local text_for_current = (function()
                    -- Generate a heading for the buffer (e.g. "Actions:")
                    local result = {
                        { { title .. ":", "TSAnnotation" } },
                        { { " ", "Normal" } }, -- This empty space marks a newline
                    }

                    -- Loop through all flags and display them accordingly:
                    for keybind, value in pairs(flags) do
                        local keybind_element = {}

                        table.insert(keybind_element, { keybind, "NeorgSelectionWindowKey" })
                        table.insert(keybind_element, { " -> ", "NeorgSelectionWindowArrow" })

                        -- If we're dealing with a table element then query its name and display it with a custom highlight
                        if type(value) == "table" then
                            table.insert(
                                keybind_element,
                                { value.name or "No description", "NeorgSelectionWindowNestedKeyName" }
                            )
                        elseif type(value) == "string" then -- If we're dealing with a string then just display it
                            table.insert(keybind_element, { value, "NeorgSelectionWindowKeyName" })
                        else
                            -- If we're dealing with something else then try to rescue the situation by stringifying whatever
                            -- the hell the user tried to provide
                            table.insert(keybind_element, { tostring(value), "NeorgSelectionWindowKeyName" })
                        end

                        -- Insert this keybind element into the result, creating a table that looks like { { { text, highlight } } }
                        -- Every top-level table element should be displayed on a new line
                        table.insert(result, keybind_element)
                    end

                    return result
                end)()

                -- Go through each "line" that the generator function created and try to set the extmark for that line
                for i, virt_text in ipairs(text_for_current) do
                    vim.api.nvim_buf_set_extmark(buf, module.private.namespace, i - 1, 0, {
                        virt_text = virt_text,
                        virt_text_pos = "overlay",
                    })
                end

                -- For some reason creating a buffer and then quickly polling for input causes the polling to happen first
                -- It seems that lazy redrawing is the culprit here, and so we force redraw in order to display the buffer!
                vim.cmd("redraw!")
            end

            -- Display all the values for the top-level flags
            display_values(name, config.flags)

            local location, result = config.flags, {}

            -- Loop through all flags
            --
            -- A flag table may look like this:
            --  {
            --      a = {
            --          name = "Press me",
            --          flags = {
            --              r = {
            --                  name = "A recursive flag",
            --                  flags = {
            --                      m = "More flags!"
            --                  }
            --              }
            --              m = "More flags",
            --          }
            --      }
            --  }
            --
            -- The top-level table element, "a", is the key you can press in order to execute an action.
            -- The "name" variable is the description for that keybind. If it's not provided the description "No description"
            -- will be used instead. Very informative.
            -- The "flags" variable specifies nested flags. You must provide this variable else you will get an error.
            -- The content of the "flags" variable follows the exact same syntax as the top-level flag table itself, so you
            -- can essentially keep creating nested flags forever.
            --
            -- If a value is a string rather than a table it signifies that there are no more nested keys beyond that specific key.
            -- You must provide a description for these keys.
            --
            -- Keep querying input and traverse down the table according to the description above:
            while location do
                -- Query the next input
                local input = vim.fn.getcharstr()

                -- If thatk key has been defined then
                if location[input] then
                    -- Add the current keypress to the list of provided inputs
                    table.insert(result, input)

                    -- If the next key we're going to traverse down is a string that means
                    -- we've reached the end of our parsing, there's nothing more to traverse down:
                    if type(location[input]) == "string" then
                        -- Since we're at the end of the parsing stage delete the buffer before invoking the callback
                        vim.api.nvim_buf_delete(buf, { force = true })

                        -- Invoke the user callback with all the necessary data and break
                        callback(result, { char = input, name = location[input] })

                        break
                    else -- Otherwise we must be dealing with a table
                        -- If there is no flags variable then we should error out
                        if not location[input].flags then
                            log.error(
                                'Malformed input provided to create_selection: expected a "flags" variable in subtable'
                            )

                            -- Delete the buffer, we don't need it anymore
                            vim.api.nvim_buf_delete(buf, { force = true })
                            break
                        end

                        -- Redraw the new flags
                        display_values(
                            location[input].name ~= "No description" and location[input].name or name,
                            location[input].flags
                        )
                        -- Recursively traverse down the table tree
                        location = location[input].flags
                    end
                end
            end
        end,

        ---Creates a new horizontal split at the bottom of the screen
        ---@param  name string the name of the buffer contained within the split (will have neorg:// prepended to it)
        ---@param  config table a table of <option> = <value> keypairs signifying buffer-local options for the buffer contained within the split
        create_split = function(name, config)
            vim.validate({
                name = { name, "string" },
                config = { config, "table", true },
            })

            vim.cmd("below new")

            local buf = vim.api.nvim_create_buf(false, false)

            local default_options = {
                swapfile = false,
                bufhidden = "hide",
                buftype = "nofile",
            }

            vim.api.nvim_buf_set_name(buf, "neorg://" .. name)

            vim.api.nvim_win_set_buf(0, buf)

            -- Merge the user provided options with the default options and apply them to the new buffer
            module.public.apply_buffer_options(buf, vim.tbl_extend("keep", config or {}, default_options))

            return buf
        end,
    }
end
