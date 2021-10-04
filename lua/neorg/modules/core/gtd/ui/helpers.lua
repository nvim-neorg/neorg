return function(module)
    return {
        public = {},

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
            --
            ---Use the table_output in order to arrange the syntax field as a string
            ---@param syntax_type table one of the syntaxes of module.private.syntax
            ---@param tbl_output table the table to arrange
            ---@return string output the formatted output
            output_formatter = function(syntax_type, tbl_output)
                local text
                if syntax_type.is_date then
                    text = module.required["coree.gtd.queries"].date_converter(tbl_output[1])
                else
                    text = table.concat(tbl_output, " ")
                end
                local output = syntax_type.output .. text .. "\n"
                return output
            end,
        },
    }
end
