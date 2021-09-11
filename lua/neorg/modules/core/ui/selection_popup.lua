--[[
    A UI module to allow the user to press different keys to select different actions
--]]

return function(module)
    return {
        public = {
            create_selection = function(name, config, callback)
                vim.validate({
                    name = { name, "string" },
                    config = { config, "table" },
                    callback = { callback, "function" },
                })

                -- Create a new horizontal split, we'll be placing our UI elements here
                local buf = module.public.create_split("selection/" .. name, config.buffer_options)

                vim.notify("Press <Esc> to quit the window")

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
                        vim.split((" \n"):rep(#vim.tbl_keys(flags) + 1), "\n", true)
                    )

                    -- Convert our table format into one that Neovim's extmarks API can understand
                    local text_for_current = (function()
                        -- Generate a heading for the buffer (e.g. "Actions:")
                        local result = {
                            { { title .. ":", "TSAnnotation" } },
                            { { " ", "Normal" } }, -- This empty space marks a newline
                        }

                        -- Loop through all flags and display them accordingly:
                        for _, data in ipairs(flags) do
                            local keybind = data[1] or ""
                            local value = data[2]

                            -- A key can only consist of one char, enforce this rule here:
                            if keybind:len() ~= 1 then
                                table.insert(result, {
                                    keybind:len() == 0 and " " or keybind,
                                    data[3] and "TSStrike" or (value or "TSPunctDelimiter"),
                                })
                            else
                                local keybind_element = {}

                                local highlights = {
                                    key = "NeorgSelectionWindowKey",
                                    key_name = "NeorgSelectionWindowKeyName",
                                    arrow = "NeorgSelectionWindowArrow",
                                    nested_key_name = "NeorgSelectionWindowNestedKeyName",
                                }

                                if data[3] then
                                    highlights = {
                                        key = "TSStrike",
                                        key_name = "TSStrike",
                                        arrow = "TSStrike",
                                        nested_key_name = "TSStrike",
                                    }
                                end

                                table.insert(keybind_element, { keybind, highlights.key })
                                table.insert(keybind_element, { " -> ", highlights.arrow })

                                -- If we're dealing with a table element then query its name and display it with a custom highlight
                                if type(value) == "table" then
                                    table.insert(keybind_element, {
                                        "+" .. (value.display and value.display or (value.name or "No description")),
                                        highlights.nested_key_name,
                                    })
                                elseif type(value) == "string" then -- If we're dealing with a string then just display it
                                    table.insert(keybind_element, { value, highlights.key_name })
                                else
                                    -- If we're dealing with something else then try to rescue the situation by stringifying whatever
                                    -- the hell the user tried to provide
                                    table.insert(keybind_element, { tostring(value), highlights.key_name })
                                end

                                -- Insert this keybind element into the result, creating a table that looks like { { { text, highlight } } }
                                -- Every top-level table element should be displayed on a new line
                                table.insert(result, keybind_element)
                            end
                        end

                        return result
                    end)()

                    if not text_for_current or vim.tbl_isempty(text_for_current) then
                        log.info("At '" .. name .. "' - no keys provided, exiting selection popup prematurely")
                        return false
                    end

                    -- Go through each "line" that the generator function created and try to set the extmark for that line
                    for i, virt_text in ipairs(text_for_current) do
                        if type(virt_text[1]) == "string" then
                            vim.api.nvim_buf_set_extmark(buf, module.private.namespace, i - 1, 0, {
                                hl_group = virt_text[2],
                                virt_text = { { virt_text[1], virt_text[2] } },
                                virt_text_pos = "overlay",
                            })
                        else
                            vim.api.nvim_buf_set_extmark(buf, module.private.namespace, i - 1, 0, {
                                virt_text = virt_text,
                                virt_text_pos = "overlay",
                            })
                        end
                    end

                    -- For some reason creating a buffer and then quickly polling for input causes the polling to happen first
                    -- It seems that lazy redrawing is the culprit here, and so we force redraw in order to display the buffer!
                    vim.cmd("redraw!")

                    return true
                end

                -- Display all the values for the top-level flags
                if not display_values(name, config.flags) then
                    return
                end

                local location, result = config.flags, {}

                -- TODO: Remake documentation
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
                    -- Query the next input (NOTE: we do getchar() rather than getcharstr() in order
                    -- to maintain better compatibility)
                    local input, char = "", vim.fn.getchar()

                    if type(char) == "number" then
                        input = string.char(char)
                        -- TODO: Maybe add support for <BS>?
                        --[[ elseif type(char) == "string" then
                	    input = char ]]
                    end

                    -- If the entered char was an <Esc> key then bail
                    if input == "" then
                        -- Delete the buffer and break out of the loop
                        vim.api.nvim_buf_delete(buf, { force = true })
                        break
                    end

                    local data = vim.tbl_filter(function(data)
                        return data[1] and data[1]:len() == 1 and data[1] ~= "\n" and data[1] == input
                    end, location)

                    data = data and data[1]

                    -- If that key has been defined and it is enabled then
                    if data and not vim.tbl_isempty(data) and not data[3] then
                        -- Add the current keypress to the list of provided inputs
                        table.insert(result, input)

                        -- TODO: Docs

                        -- If the next key we're going to traverse down is a string that means
                        -- we've reached the end of our parsing, there's nothing more to traverse down:
                        if type(data[2]) == "string" then
                            -- Since we're at the end of the parsing stage delete the buffer before invoking the callback
                            vim.api.nvim_buf_delete(buf, { force = true })

                            -- Invoke the user callback with all the necessary data and break
                            callback(result, { char = input, name = data[2] })

                            break
                        else -- Otherwise we must be dealing with a table
                            -- If there is no flags variable then we should error out
                            if not data[2].flags then
                                log.error(
                                    'Malformed input provided to create_selection: expected a "flags" variable in subtable'
                                )

                                -- Delete the buffer, we don't need it anymore
                                vim.api.nvim_buf_delete(buf, { force = true })
                                break
                            end

                            -- Redraw the new flags
                            if
                                not display_values(
                                    data[2].name ~= "No description" and data[2].name or name,
                                    data[2].flags
                                )
                            then
                                -- Delete the buffer, we don't need it anymore
                                vim.api.nvim_buf_delete(buf, { force = true })
                                break
                            end
                            -- Recursively traverse down the table tree
                            location = data[2].flags
                        end
                    end
                end
            end,
        },
    }
end
