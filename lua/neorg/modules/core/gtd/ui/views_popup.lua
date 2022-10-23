--[[
    Submodule responsible for creating API for gtd views
--]]

local module = neorg.modules.extend("core.gtd.ui.views_popup", "core.gtd.ui")

---@class core.gtd.ui
module.public = {

    --- Function called when doing `:Neorg gtd views`
    ---@param tasks core.gtd.queries.task[]
    ---@param projects core.gtd.queries.project[]
    show_views_popup = function(tasks, projects)
        -- Generate views selection popup
        local buffer = module.required["core.ui"].create_split("Quick Actions")

        if not buffer then
            return
        end

        local selection = module.required["core.ui"]
            .begin_selection(buffer)
            :listener("destroy", { "<Esc>" }, function(self)
                self:destroy()
            end)

        selection:title("Views"):blank():concat(function()
            return module.private.generate_display_flags(selection, tasks, projects)
        end)

        module.public.display_messages()
    end,
}

--- @class private_core.gtd.ui
module.private = {
    --- Generates flags for gtd views
    ---@param selection core.ui.selection
    ---@param tasks core.gtd.queries.task[]
    ---@param projects core.gtd.queries.project[]
    ---@return core.ui.selection
    generate_display_flags = function(selection, tasks, projects)
        local is_processed_cb = module.public.get_callback("is_processed")
        local unclarified_tasks = vim.tbl_filter(neorg.lib.wrap_cond_not(is_processed_cb, projects), tasks)
        local unclarified_projects = vim.tbl_filter(neorg.lib.wrap_cond_not(is_processed_cb, tasks), projects)
        local clarified_projects = vim.tbl_filter(neorg.lib.wrap_cond(is_processed_cb, tasks), projects)
        local clarified_tasks = vim.tbl_filter(neorg.lib.wrap_cond(is_processed_cb, projects), tasks)

        selection
            :text("All tasks and projects")
            :flag("a", "All tasks", neorg.lib.wrap(module.public.display_all_tasks, tasks))
            :flag("A", "All projects", neorg.lib.wrap(module.public.display_projects, tasks, projects))
            :blank()
            :text("Unclarified")
            :flag(
                "u",
                "Unclarified tasks",
                neorg.lib.wrap(module.public.display_unclarified, "task", unclarified_tasks)
            )
            :flag(
                "U",
                "Unclarified projects",
                neorg.lib.wrap(module.public.display_unclarified, "project", unclarified_projects, unclarified_tasks)
            )
            :blank()
            :text("Top priorities")
            :flag("s", "Weekly Summary", neorg.lib.wrap(module.public.display_weekly_summary, clarified_tasks))
            :flag("t", "Today's tasks", neorg.lib.wrap(module.public.display_today_tasks, clarified_tasks))
            :flag(
                "p",
                "Show projects",
                neorg.lib.wrap(module.public.display_projects, clarified_tasks, clarified_projects)
            )
            :blank()
            :text("Sort and filter tasks")
            :flag(
                "c",
                "Contexts",
                neorg.lib.wrap(
                    module.public.display_contexts,
                    clarified_tasks,
                    { exclude = { "someday" }, priority = { "_" } }
                )
            )
            :flag("w", "Waiting For", neorg.lib.wrap(module.public.display_waiting_for, clarified_tasks))
            :flag("d", "Someday Tasks", neorg.lib.wrap(module.public.display_someday, clarified_tasks))
            :blank()
            :concat(module.private.generate_informations)
        return selection
    end,

    --- Show informations flag
    ---@param selection core.ui.selection
    generate_informations = function(selection)
        local function files_text(files)
            if not files then
                return selection:text("No files found")
            end

            for _, file in pairs(files) do
                selection:text("- " .. file, "@comment")
            end
            return selection
        end

        local files = module.required["core.gtd.helpers"].get_gtd_files()
        local excluded_files = module.required["core.gtd.helpers"].get_gtd_excluded_files()
        return selection:text("Advanced"):flag("i", "Show more informations", {
            callback = function()
                selection:push_page()
                selection
                    :title("GTD informations")
                    :blank()
                    :flag("<BS>", "Return to main page", {
                        callback = function()
                            selection:pop_page()
                        end,
                        destroy = false,
                    })
                    :blank()
                    :text("Files used for GTD")
                    :concat(neorg.lib.wrap(files_text, files))
                    :blank()
                    :text("Files excluded")
                    :concat(neorg.lib.wrap(files_text, excluded_files))
            end,
            destroy = false,
        })
    end,
}

return module
