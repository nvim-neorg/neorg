--[[
    Base module for Getting Things Done methodology

USAGE:
    - To add a task to the inbox:
        - Use the public function add_task_to_inbox()
        - Call the command :Neorg gtd capture

REQUIRES:
    This module requires:
        - core.norg.dirman in order to get full path to the workspace
        - core.keybinds (check KEYBINDS for usage)
        - core.ui in order to ask for user input
        - core.neorgcmd to add commands capabilities

KEYBINDS:
    - core.gtd.base.add_to_inbox: Will call the function add_task_to_inbox()

--]]

require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.gtd.base")
local log = require('neorg.external.log')

module.setup = function ()
    return {
        success = true,
        requires = { 'core.norg.dirman', 'core.keybinds', 'core.ui', 'core.neorgcmd' }
    }
end

module.config.public = {
    -- Workspace name to use for gtd related lists
    workspace = "default",
    default_lists = {
        inbox = "inbox.norg"
    }
}

module.private = {
    workspace_full_path = nil,
    syntax = {
        context = { prefix = "@", pattern = "@[%w%d]+" },
        project_single_word = { prefix = "+" , pattern = '+[%w%d]+' },
        project_multiple_words = { prefix = '+"' , pattern = '+"[%w%d%s]+"', suffix = '"' },
        due = { prefix = "$due:", pattern = "$due:[%d-%w]+" },
        start = { prefix = "$start:", pattern = "$start:[%d-%w]+" }
    },

---@Summary Append text to list
---@Description Append the text to the specified list (defined in config.public.default_lists)
---@Param  list (string) the list to use
---@Param  text (string) the text to append
    add_to_list = function (list, text)
        local fn = io.open(module.private.workspace_full_path .. "/" .. list, "a")
        fn:write(text)
        fn:flush()
        fn:close()
    end,

-- @Summary Find the specified syntax defined in module.private.syntax
-- @Description Return a table containing the found elements belonging to the specified syntax in a text
-- @Param  text (string) the text to find in
-- @Param  syntax_type (module.private.syntax)
    find_syntaxes = function (text, syntax_type)
        local suffix_len
        if syntax_type.suffix then suffix_len = #syntax_type.suffix end
        return module.private.parse_content(text, syntax_type.pattern, #syntax_type.prefix, suffix_len or nil)
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
    date_converter = function (text)
        -- Get today's date
        local now = os.date("%Y-%m-%d")
        local y,m,d = now:match("(%d+)-(%d+)-(%d+)")

        -- Cases for converting quick dates to full dates (e.g 1w is one week from now)
        local converted_date
        local patterns = { weeks = "[%d]+w", days = "[%d]+d", months = "[%d]+m" }
        local days_matched = text:match(patterns.days)
        local weeks_matched = text:match(patterns.weeks)
        local months_matched = text:match(patterns.months)
        if text == "tomorrow" then
           converted_date = os.time{year = y, month = m, day = d + 1 }
        elseif text == "today" then
            return now
        elseif weeks_matched ~= nil then
            converted_date = os.time{year = y, month = m, day = d + 7 * weeks_matched:sub(1,-2)}
        elseif days_matched ~= nil then
            converted_date = os.time {year = y, month = m, day = d + days_matched:sub(1,-2) }
        elseif months_matched ~= nil then
            converted_date = os.time {year = y, month = m + months_matched:sub(1,-2), day = d }
        else return text end
        return os.date("%Y-%m-%d", converted_date)
    end,

-- @Summary Parse content from text with a specific pattern
-- @Description Will try to use the pattern to return a table of elements that match the pattern
-- @Param  text (string)
-- @Param  pattern (string)
-- @Param  size_delimiter (string) the delimiter size before the actual content (e.g $due:2w has size of 5, which is $due:)
    parse_content = function (text, pattern, size_delimiter_left, size_delimiter_right)
        local _size_delimiter_right = size_delimiter_right or 0
        local capture = text:gmatch(pattern)
        local content = {}
        for w in capture do
            table.insert(content, w:sub(size_delimiter_left + 1, (#w - _size_delimiter_right) or -1))
        end
        return content
    end,
}

module.load = function ()
    -- Get workspace for gtd files and save full path in private
    local workspace = module.config.public.workspace
    module.private.workspace_full_path = module.required["core.norg.dirman"].get_workspace(workspace)

    -- Register keybinds
    module.required["core.keybinds"].register_keybind(module.name, "add_to_inbox")

    -- Add neorgcmd capabilities
    -- All gtd commands are start with :Neorg gtd ...
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            gtd = {
                capture = {},
                list = { inbox = {} }
            }
        },
        data = {
            gtd = {
                args = 1,
                subcommands = {
                    capture = { args = 0, name = "gtd.capture" },
                    list = { args = 1, name = "gtd.list", subcommands = {
                        inbox = { args = 0, name = "gtd.list.inbox" }
                    } }
                }
            }
        }
    })

end

module.on_event = function (event)
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
        end
    end
end

module.public = {
    version = "0.2",

-- @Summary Add user task to inbox
-- @Description Show prompt asking for user input and append the task to the inbox
    add_task_to_inbox = function ()
        -- Define a callback (for prompt) to add the task to the inbox list
        local cb = function (text)
            local contexts = module.private.find_syntaxes(text, module.private.syntax.context)
            local projects_single = module.private.find_syntaxes(text, module.private.syntax.project_single_word)
            local projects_multiple = module.private.find_syntaxes(text, module.private.syntax.project_multiple_words)
            local projects = vim.tbl_extend("force", projects_single, projects_multiple)
            local due_dates = module.private.find_syntaxes(text, module.private.syntax.due)
            local start_dates = module.private.find_syntaxes(text, module.private.syntax.start)
            log.info("Contexts: ", contexts)
            log.info("Project: ", projects)
            log.info("Due dates: ", due_dates)
            log.info("Start dates: ", start_dates)

            if #projects > 1 then log.error("Please specify max 1 project") return end
            if #due_dates > 1 then log.error("Please specify max 1 due date") return end
            if #start_dates > 1 then log.error("Please specify max 1 start date") return end

            local contexts_output = ""
            local project_output = ""
            local due_date_output = ""
            local start_date_output = ""
            local task_output = "- [ ] " .. text:match('^[^@+$]*') .. "\n" -- Everything before $, @, or +

            if #projects ~= 0 then
                project_output = "* " .. projects[1] .. "\n"
            end

            if #contexts ~= 0 then
                contexts_output = "** " .. table.concat(contexts, " ") .. "\n" -- Iterate through contexts
            end

            if #due_dates ~= 0 then
                due_date_output = "$due:" .. module.private.date_converter(due_dates[1]) .. "\n"
            end

            if #start_dates ~= 0 then
                start_date_output = "$start:" .. module.private.date_converter(start_dates[1]) .. "\n"
            end


            local output = project_output .. contexts_output .. due_date_output .. start_date_output .. task_output
            module.private.add_to_list(
                module.config.public.default_lists.inbox,
                output
            )

            log.info("Added " .. task_output .. "to " .. module.private.workspace_full_path)
        end

        -- Show prompt asking for input
        module.required["core.ui"].create_prompt(
            "INBOX_WINDOW",
            "Add to inbox.norg > ",
            cb,
            {
                center_x = true,
                center_y = true,
            },
            {
                width = 60,
                height = 1,
                row = 1,
                col = 1
            })

    end
}

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.base.add_to_inbox"] = true
    },
    ["core.neorgcmd"] = {
        ["gtd.capture"] = true,
        ["gtd.list.inbox"] = true
    }
}

return module
