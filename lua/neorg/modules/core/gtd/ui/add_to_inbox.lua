return function(module)
    return {
        public = {

            -- @Summary Add user task to inbox
            -- @Description Show prompt asking for user input and append the task to the inbox
            add_task_to_inbox = function()
                -- Define a callback (for prompt) to add the task to the inbox list
                local cb = function(text, actions)
                    local results = {}
                    -- Add found_syntaxes to results and check for uniqueness
                    for name, syntax in pairs(module.private.syntax) do
                        results[name] = module.private.find_syntaxes(text, syntax)
                        if syntax.unique == true and #results[name] > 1 then
                            log.error("Please specify max 1 " .. name)
                            actions.close()
                            return
                        end
                    end

                    -- Format each found syntax and rearrange priority
                    local output_table = {}
                    for syntax, content in pairs(results) do
                        if #content ~= 0 then
                            local priority = module.private.syntax[syntax].priority
                            local formatted_content = module.private.output_formatter(
                                module.private.syntax[syntax],
                                content
                            )
                            table.insert(output_table, priority, formatted_content)
                        end
                    end

                    -- Output each syntax node
                    local output = ""
                    for _, value in pairs(output_table) do
                        output = output .. value
                    end

                    local configs = neorg.modules.get_module_config("core.gtd.base")
                    module.private.add_to_list(configs.default_lists.inbox, output)
                    actions.close()
                end

                -- Show prompt asking for input
                module.required["core.ui"].create_prompt("INBOX_WINDOW", "Add to inbox.norg > ", cb, {
                    center_x = true,
                    center_y = true,
                }, {
                    width = 60,
                    height = 1,
                    row = 3,
                    col = 0,
                })
            end,
        },

        private = {

            -- The syntax to use for gtd.
            -- Model: [syntax_name] = { syntax }
            -- It is fully customizable, with the parameters below:
            -- prefix: the prefix of the syntax_type
            -- suffix: (optional) the suffix of the syntax_type
            -- pattern: the pattern to use to find all occurences of the syntax_type
            -- output: the output written in .norg file
            -- priority: priority of the syntax in the .norg file (1 will be the first to be added)
            -- unique: (optional, default false) raises an error if we accept only one occurence of it
            syntax = {
                project = {
                    prefix = '+"',
                    pattern = '+"[%w%d%s]+"',
                    suffix = '"',
                    output = "* ",
                    priority = 1,
                    unique = true,
                },
                context = { prefix = "@", pattern = "@[%w%d]+", output = "** ", priority = 2 },
                due = {
                    prefix = "$due:",
                    pattern = "$due:[%d-%w]+",
                    output = "$due:",
                    is_date = true,
                    priority = 3,
                    unique = true,
                },
                start = {
                    prefix = "$start:",
                    pattern = "$start:[%d-%w]+",
                    output = "$start:",
                    is_date = true,
                    priority = 4,
                    unique = true,
                },
                note = {
                    prefix = '$note:"',
                    pattern = '$note:"[%w%d%s]+"',
                    suffix = '"',
                    output = "$note:",
                    priority = 5,
                    unique = true,
                },
                task = { pattern = "^[^@+$]*", single_capture = true, output = "- [ ] ", priority = 6, unique = true },
            },

            ---@Summary Append text to list
            ---@Description Append the text to the specified list (defined in config.public.default_lists)
            ---@Param  list (string) the list to use
            ---@Param  text (string) the text to append
            add_to_list = function(list, text)
                local configs = neorg.modules.get_module_config("core.gtd.base")
                local workspace = module.required["core.norg.dirman"].get_workspace(configs.workspace)

                local fn = io.open(workspace .. "/" .. list, "a")
                if fn then
                    fn:write(text)
                    fn:flush()
                    fn:close()
                end
            end,

            -- @Summary Find the specified syntax defined in module.private.syntax
            -- @Description Return a table containing the found elements belonging to the specified syntax in a text
            -- @Param  text (string) the text to find in
            -- @Param  syntax_type (module.private.syntax)
            find_syntaxes = function(text, syntax_type)
                local suffix_len
                local prefix_len
                if syntax_type.suffix then
                    suffix_len = #syntax_type.suffix
                end
                if syntax_type.prefix then
                    prefix_len = #syntax_type.prefix
                end
                return module.private.parse_content(
                    text,
                    syntax_type.pattern,
                    prefix_len or nil,
                    suffix_len or nil,
                    syntax_type.single_capture
                )
            end,

            -- @Summary Parse content from text with a specific pattern
            -- @Description Will try to use the pattern to return a table of elements that match the pattern
            -- @Param  text (string)
            -- @Param  pattern (string)
            -- @Param  size_delimiter (string) the delimiter size before the actual content (e.g $due:2w has size of 5, which is $due:)
            parse_content = function(text, pattern, size_delimiter_left, size_delimiter_right, single_capture)
                local _size_delimiter_right = size_delimiter_right or 0
                local _size_delimiter_left = size_delimiter_left or -1
                local capture
                local content = {}
                if single_capture ~= nil then
                    capture = text:match(pattern)
                    if #capture ~= 0 then
                        table.insert(content, capture)
                    end
                else
                    capture = text:gmatch(pattern)
                    for w in capture do
                        table.insert(content, w:sub(_size_delimiter_left + 1, (#w - _size_delimiter_right) or -1))
                    end
                end
                return content
            end,

            -- @Summary Convert a date from text to YY-MM-dd format
            -- @Description If the date is a quick capture (like 2w, 10d, 4m), it will convert to a standardized date
            -- Supported formats ($ treated as number):
            --   - $d: days from now (e.g 2d is 2 days from now)
            --   - $w: weeks from now (e.g 2w is 2 weeks from now)
            --   - $m: months from now (e.g 2m is 2 months from now)
            --   - tomorrow: tomorrow's date
            --   - today: today's date
            --   The format for date is YY-mm-dd
            -- @Param  text (string) the text to use
            date_converter = function(text)
                -- Get today's date
                local now = os.date("%Y-%m-%d")
                local y, m, d = now:match("(%d+)-(%d+)-(%d+)")

                -- Cases for converting quick dates to full dates (e.g 1w is one week from now)
                local converted_date
                local patterns = { weeks = "[%d]+w", days = "[%d]+d", months = "[%d]+m" }
                local days_matched = text:match(patterns.days)
                local weeks_matched = text:match(patterns.weeks)
                local months_matched = text:match(patterns.months)
                if text == "tomorrow" then
                    converted_date = os.time({ year = y, month = m, day = d + 1 })
                elseif text == "today" then
                    return now
                elseif weeks_matched ~= nil then
                    converted_date = os.time({ year = y, month = m, day = d + 7 * weeks_matched:sub(1, -2) })
                elseif days_matched ~= nil then
                    converted_date = os.time({ year = y, month = m, day = d + days_matched:sub(1, -2) })
                elseif months_matched ~= nil then
                    converted_date = os.time({ year = y, month = m + months_matched:sub(1, -2), day = d })
                else
                    return text
                end
                return os.date("%Y-%m-%d", converted_date)
            end,

            ---Use the table_output in order to arrange the syntax field as a string
            ---@param syntax_type table one of the syntaxes of module.private.syntax
            ---@param tbl_output table the table to arrange
            ---@return string output the formatted output
            output_formatter = function(syntax_type, tbl_output)
                local text
                if syntax_type.is_date then
                    text = module.private.date_converter(tbl_output[1])
                else
                    text = table.concat(tbl_output, " ")
                end
                local output = syntax_type.output .. text .. "\n"
                return output
            end,
        },
    }
end
