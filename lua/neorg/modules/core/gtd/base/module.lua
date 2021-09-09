--[[
    Base module for Getting Things Done methodology

USAGE:
    - Quick actions for gtd stuff:
        - Call the command :Neorg gtd quick_actions
    - To add a task to the inbox:
        - Use the public function add_task_to_inbox()
        - Call the command :Neorg gtd capture

REQUIRES:
    This module requires:
        - core.norg.dirman in order to get full path to the workspace
        - core.keybinds (check KEYBINDS for usage)
        - core.ui in order to ask for user input
        - core.neorgcmd to add commands capabilities
        - core.queries.native to fetch content from norg files

KEYBINDS:
    - core.gtd.base.add_to_inbox: Will call the function add_task_to_inbox()

--]]

require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.gtd.base")
local utils = require("neorg.external.helpers")
local log = require("neorg.external.log")

module.setup = function()
    return {
        success = true,
        requires = { "core.norg.dirman", "core.keybinds", "core.ui", "core.neorgcmd", "core.queries.native" },
    }
end

module.config.public = {
    -- Workspace name to use for gtd related lists
    workspace = "default",
    default_lists = {
        inbox = "inbox.norg",
    },
    exclude = {},
}

module.public = {
    version = "0.1",
}

module.public = vim.tbl_extend("error", module.public, utils.require(module, "add_to_inbox")(module))

module.private = {
    workspace_full_path = nil,

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
        project = { prefix = '+"', pattern = '+"[%w%d%s]+"', suffix = '"', output = "* ", priority = 1, unique = true },
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
        local fn = io.open(module.private.workspace_full_path .. "/" .. list, "a")
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
}

module.load = function()
    -- Get workspace for gtd files and save full path in private
    local workspace = module.config.public.workspace
    log.info(workspace)
    module.private.workspace_full_path = module.required["core.norg.dirman"].get_workspace(workspace)
    log.info(module.private.workspace_full_path)

    -- Register keybinds
    module.required["core.keybinds"].register_keybind(module.name, "add_to_inbox")

    -- Add neorgcmd capabilities
    -- All gtd commands start with :Neorg gtd ...
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            gtd = {
                capture = {},
                list = { inbox = {} },
                quick_actions = {},
            },
        },
        data = {
            gtd = {
                args = 1,
                subcommands = {
                    capture = { args = 0, name = "gtd.capture" },
                    list = {
                        args = 1,
                        name = "gtd.list",
                        subcommands = {
                            inbox = { args = 0, name = "gtd.list.inbox" },
                        },
                    },
                    quick_actions = { args = 0, name = "gtd.quick_actions" },
                },
            },
        },
    })
end

module.on_event = function(event)
    if event.split_type[2] == "core.gtd.base.add_to_inbox" then
        module.public.add_task_to_inbox()
    end
    if event.split_type[1] == "core.neorgcmd" then
        if event.split_type[2] == "gtd.capture" then
            module.public.add_task_to_inbox()
        elseif event.split_type[2] == "gtd.list.inbox" then
            module.required["core.norg.dirman"].open_file(
                module.config.public.workspace,
                module.config.public.default_lists.inbox
            )
        elseif event.split_type[2] == "gtd.quick_actions" then
            module.required["core.ui"].create_selection("Quick actions", {
                flags = {
                    { "a", "Add a task to inbox" },
                    {
                        "l",
                        {
                            name = "List files",
                            flags = {
                                { "i", "Inbox" },
                            },
                        },
                    },
                    {},
                    { "Test Queries (index.norg) file", "TSComment" },
                    { "p", "Projects" },
                    {
                        "t",
                        {
                            name = "Tasks",
                            flags = {
                                { "t", "Today tasks" },
                                { "c", "contexts" },
                                { "w", "Waiting for" },
                                { "d", "Due tasks", true },
                                { "s", "Start tasks", true },
                            },
                        },
                    },
                },
            }, function(choices)
                if choices[1] == "a" then
                    module.public.add_task_to_inbox()
                elseif choices[1] == "l" and choices[2] == "i" then
                    module.required["core.norg.dirman"].open_file(
                        module.config.public.workspace,
                        module.config.public.default_lists.inbox
                    )
                elseif choices[1] == "p" then
                    local tasks = module.private.get_tasks({ exclude_files = module.config.public.exclude })
                    local projects = module.private.get_projects({ exclude_files = module.config.public.exclude })
                    tasks = module.private.add_metadata(tasks)
                    module.private.display_projects(tasks, projects, { priority = { "_" }})
                elseif choices[1] == "t" then
                    local tasks = module.private.get_tasks({ exclude_files = module.config.public.exclude })
                    tasks = module.private.add_metadata(tasks)
                    if choices[2] == "t" then
                        module.private.display_today_tasks(tasks)
                    elseif choices[2] == "w" then
                        module.private.display_waiting_for(tasks)
                    elseif choices[2] == "s" then
                        tasks = module.private.add_metadata(tasks)
                        log.warn(tasks)
                    elseif choices[2] == "d" then
                        tasks = module.private.add_metadata(tasks)
                        log.warn(tasks)
                    elseif choices[2] == "c" then
                        module.private.display_contexts(tasks, { exclude = { "someday" }, priority = { "_" } })
                    end
                end
            end)
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.base.add_to_inbox"] = true,
    },
    ["core.neorgcmd"] = {
        ["gtd.capture"] = true,
        ["gtd.list.inbox"] = true,
        ["gtd.quick_actions"] = true,
    },
}

module.private = vim.tbl_extend("error", module.private, utils.require(module, "gtd_queries")(module))
module.private = vim.tbl_extend("error", module.private, utils.require(module, "displayers")(module))

return module
