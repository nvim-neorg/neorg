require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.gtd.base")
local log = require("neorg.external.log")

module.setup = function ()
    return { success = true, requires = { 'core.norg.dirman', 'core.keybinds' } }
end

module.config.public = {
    workspace = nil
}

module.private = {
    workspace = nil,
    default_lists = {
        inbox = "INBOX.norg",
        projects = "PROJECTS.norg",
        someday = "SOMEDAY.norg"
    }
}

module.load = function ()
    --module.public.add_task_to_inbox()
    module.private.workspace = module.config.public.workspace or "default"
    log.info('Loaded GTD')
    module.required["core.keybinds"].register_keybind(module.name, "add_to_inbox")
end

module.on_event = function (event)
    if event.split_type[2] == "core.gtd.base.add_to_inbox" then
       module.public.add_task_to_inbox()
    end
end

module.public = {
    version = "0.1",

    add_task_to_inbox = function ()
        workspace_path = module.required["core.norg.dirman"].get_workspace(module.private.workspace)
        log.info("Inbox path:", workspace_path .. "/" .. module.private.default_lists.inbox)
        log.info("Added to INBOX")
    end
}

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.base.add_to_inbox"] = true
    }
}

return module
