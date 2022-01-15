--[[
    Submodule responsible for creating API for gtd views
--]]

local module = neorg.modules.extend("core.gtd.ui.views_popup", "core.gtd.ui")

---@class core.gtd.ui
module.public = {

    --- Function called when doing `:Neorg gtd views`
    --- @param tasks core.gtd.queries.task[]
    --- @param projects core.gtd.queries.project[]
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

--- @class private_core.gtd.ui
module.private = {
    --- Generates flags for gtd views
    --- @param selection core.ui.selection
    --- @param tasks core.gtd.queries.task[]
    --- @param projects core.gtd.queries.project[]
    --- @return core.ui.selection
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
            :blank()
            :concat(module.private.generate_informations)
        return selection
    end,

    --- Show informations flag
    --- @param selection core.ui.selection
    generate_informations = function(selection)
        local function files_text(_selection, files)
            if not files then
                return _selection:text("No files found")
            end

            for _, file in pairs(files) do
                _selection:text("- " .. file, "TSComment")
            end
            return _selection
        end

        local files = module.required["core.gtd.helpers"].get_gtd_files()
        local excluded_files = module.required["core.gtd.helpers"].get_gtd_excluded_files()
        return selection:text("Advanced"):flag("i", "Show more informations", {
            callback = function()
                selection:push_page()
                selection
                    :title("GTD informations")
                    :blank()
                    :text("Files used for GTD")
                    :concat(neorg.lib.wrap(files_text, selection, files))
                    :blank()
                    :text("Files excluded")
                    :concat(neorg.lib.wrap(files_text, selection, excluded_files))
                    :blank()
                    :flag("<CR>", "Return to main page", {
                        callback = function()
                            selection:pop_page()
                        end,
                        destroy = false,
                    })
            end,
            destroy = false,
        })
    end,
}

return module
