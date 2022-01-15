local module = neorg.modules.extend("core.gtd.ui.views_popup", "core.gtd.ui")

---@class core.gtd.ui
module.public = {

    show_views_popup = function(tasks, projects)
        -- Generate views selection popup
        local buffer = module.required["core.ui"].create_split("Quick Actions")

        if not buffer then
            return
        end

        local selection = module.required["core.ui"].begin_selection(buffer):listener(
            "destroy",
            { "<Esc>" },
            function(self)
                self:destroy()
            end
        )

        selection:title("Views"):blank():concat(function(_selection)
            return module.private.generate_display_flags(_selection, tasks, projects)
        end)

        module.public.display_messages()
    end,
}

module.private = {
    generate_display_flags = function(selection, tasks, projects)
        selection
            :text("Top priorities")
            :flag("s", "Weekly Summary", function()
                module.public.display_weekly_summary(tasks)
            end)
            :blank()
            :text("Tasks")
            :flag("t", "Today's tasks", function()
                module.public.display_today_tasks(tasks)
            end)
            :blank()
            :text("Sort and filter tasks")
            :flag("c", "Contexts", function()
                module.public.display_contexts(tasks, { exclude = { "someday" }, priority = { "_" } })
            end)
            :flag("w", "Waiting For", function()
                module.public.display_waiting_for(tasks)
            end)
            :flag("d", "Someday Tasks", function()
                module.public.display_someday(tasks)
            end)
            :blank()
            :text("Projects")
            :flag("p", "Show projects", function()
                module.public.display_projects(tasks, projects)
            end)
        return selection
    end,
}

return module
