local module = neorg.modules.extend("core.gtd.ui.helpers", "core.gtd.ui")

---@class core.gtd.ui
module.public = {
    get_data_for_views = function()
        -- Exclude files explicitely provided by the user, and the inbox file
        local configs = neorg.modules.get_module_config("core.gtd.base")
        local exclude_files = configs.exclude
        table.insert(exclude_files, configs.default_lists.inbox)

        -- Reset state of previous fetches
        module.required["core.queries.native"].delete_content()

        -- Get tasks and projects
        local tasks = module.required["core.gtd.queries"].get("tasks", { exclude_files = exclude_files })
        local projects = module.required["core.gtd.queries"].get("projects", { exclude_files = exclude_files })

        -- Error out when no projects
        if not tasks or not projects then
            return
        end

        tasks = module.required["core.gtd.queries"].add_metadata(tasks, "task")
        projects = module.required["core.gtd.queries"].add_metadata(projects, "project")

        return tasks, projects
    end,

    display_messages = function()
        vim.cmd(string.format([[echom '%s']], "Press ESC to exit without saving"))
    end,
}

return module
