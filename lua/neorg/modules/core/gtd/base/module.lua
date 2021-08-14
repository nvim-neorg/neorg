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

-- @Summary Find all contexts in a string
-- @Description Retrieve all contexts (e.g @home) and output to a table
-- @Param  text (string) the text to find contexts
    find_contexts = function (text)
        local pattern = "@[%w%d]+"
        return module.private.parse_content(text, pattern, 1)
    end,

-- @Summary Find all projects in a string
-- @Description Retrieve all projects (e.g +"This is a Project" or +Project) and output to a table
-- @Param  text (string) the text to find projects
    find_projects = function (text)
        local pattern1 = '+[%w%d]+' -- e.g +Project
        local pattern2 = '+"[%w%d%s]+"' -- e.g +"This is a project"
        local found_projects_single_word = module.private.parse_content(text, pattern1, 1)
        local found_projects_multiple_words = module.private.parse_content(text, pattern2, 2, 1)
        return vim.tbl_extend("force", found_projects_multiple_words, found_projects_single_word)
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
    end
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
    version = "0.1",

-- @Summary Add user task to inbox
-- @Description Show prompt asking for user input and append the task to the inbox
    add_task_to_inbox = function ()
        -- Define a callback (for prompt) to add the task to the inbox list
        local cb = function (text)
            local contexts = module.private.find_contexts(text)
            local projects = module.private.find_projects(text)
            log.info("Contexts: ", contexts)
            log.info("Project: ", projects)

            if #projects > 1 then
                log.error("Please specify max 1 project")
                return
            end

            local contexts_output = ""
            local project_output = ""
            local task_output = "- [ ] " .. text:match('^[^@+$]*') -- Everything before $, @, or +

            if #projects ~= 0 then
                project_output = "* " .. projects[1] .. "\n"
            end

            if #contexts ~= 0 then
                test = {}
                contexts_output = "** " .. table.concat(contexts, " ") .. "\n" -- Iterate through contexts
            end

            local output = project_output .. contexts_output .. task_output
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
