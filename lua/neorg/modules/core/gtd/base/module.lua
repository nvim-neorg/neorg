require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.gtd.base")

module.setup = function ()
    return {
        success = true,
        requires = { 'core.norg.dirman', 'core.keybinds', 'core.ui' }
    }
end

module.config.public = {
    workspace = nil
}

module.private = {
    workspace_full_path = nil,
    default_lists = {
        inbox = "INBOX.norg",
        projects = "PROJECTS.norg",
        someday = "SOMEDAY.norg"
    },

-- @Summary Append text to list
-- @Description Append the text to the specified list (defined in private.default_lists)
-- @Param  list (string) the list to use
-- @Param  text (string) the text to append
    add_to_list = function (list, text)
        local fn = io.open(module.private.workspace_full_path .. "/" .. list, "a")
        fn:write(text)
        fn:flush()
        fn:close()
    end
}

module.load = function ()
    -- Get workspace for gtd files and save full path in private
    local workspace = module.config.public.workspace or "default"
    module.private.workspace_full_path = module.required["core.norg.dirman"].get_workspace(workspace)

    -- Register keybinds
    module.required["core.keybinds"].register_keybind(module.name, "add_to_inbox")
end

module.on_event = function (event)
    if event.split_type[2] == "core.gtd.base.add_to_inbox" then
        module.public.add_task_to_inbox()
    end
end

module.public = {
    version = "0.1",

-- @Summary Add user task to inbox
-- @Description Show prompt asking for user input and append the task to the inbox
    add_task_to_inbox = function ()
        -- Define a callback (for prompt) to add the task to the inbox list
        local cb = function (text)
            module.private.add_to_list(module.private.default_lists.inbox, "- [ ] " .. text .. "\n")
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
    }
}

return module
