local module = neorg.modules.extend("core.gtd.ui.views_popup_helpers")

module.private = {
    --- Generate flags for specific mode (date related)
    --- @param selection table
    --- @param task core.gtd.queries.task
    --- @param mode string #Date mode to use: start|due
    --- @param flag string #The flag to use
    --- @return table #`selection`
    generate_date_flags = function(selection, task, mode, flag)
        local title = "Add a " .. mode .. " date"
        return selection:rflag(flag, title, function()
            selection
                :listener("go-back", { "<BS>" }, function(self)
                    self:pop_page()
                end)
                :title(title)
                :blank()
                :text("Static Times:")
                :flag("d", "Today", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("today")
                        selection:pop_page()
                    end,
                })
                :flag("t", "Tomorrow", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("tomorrow")
                        selection:pop_page()
                    end,
                })
                :flag("w", "Next week", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("1w")
                        selection:pop_page()
                    end,
                })
                :flag("m", "Next month", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("1m")
                        selection:pop_page()
                    end,
                })
                :flag("y", "Next year", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("1y")
                        selection:pop_page()
                    end,
                })
                :blank()
                :rflag("c", "Custom", {
                    destroy = false,
                    callback = function()
                        selection
                            :title("Custom Date")
                            :text("Allowed date: today, tomorrow, Xw, Xd, Xm, Xy (where X is a number)")
                            :text("You can even use 'mon', 'tue', 'wed' ... for the next weekday date")
                            :blank()
                            :prompt("Due", {
                                callback = function(text)
                                    if #text > 0 then
                                        task[mode] = module.required["core.gtd.queries"].date_converter(text)

                                        if not task[mode] then
                                            log.error("Date format not recognized, please try again...")
                                        else
                                            selection:pop_page()
                                        end
                                    end
                                end,
                                pop = true,
                            })
                    end,
                })
        end)
    end,

    --- Generate flags for specific mode
    --- @param selection table
    --- @param task core.gtd.queries.task
    --- @param mode string #Date mode to use: waiting_for|contexts
    --- @param flag string #The flag to use
    --- @return table #`selection`
    generate_default_flags = function(selection, task, mode, flag)
        if not vim.tbl_contains({ "contexts", "waiting.for" }, mode) then
            log.error("Invalid mode")
            return
        end

        local title = (function()
            if mode == "contexts" then
                return "Add Contexts"
            elseif mode == "waiting.for" then
                return "Add Waiting Fors"
            end
        end)()

        return selection:rflag(flag, title, {
            destroy = false,
            callback = function()
                selection
                    :listener("go-back", { "<BS>" }, function(self)
                        self:pop_page()
                    end)
                    :title(title)
                    :text("Separate multiple values with space")
                    :blank()
                    :prompt(title, {
                        callback = function(text)
                            if #text > 0 then
                                task[mode] = task[mode] or {}
                                task[mode] = vim.list_extend(task[mode], vim.split(text, " ", false))
                            end
                        end,
                        pop = true,
                    })
            end,
        })
    end,

    generate_project_flags = function(selection, task, flag)
        return selection:flag(flag, "Add to project", {
            callback = function()
                selection:push_page()

                selection:title("Add to project"):blank():text("Append task to existing project")

                -- Get all projects
                local projects = module.required["core.gtd.queries"].get("projects")
                --- @type core.gtd.queries.project
                projects = module.required["core.gtd.queries"].add_metadata(projects, "project")

                for i, project in pairs(projects) do
                    local f = module.private.create_flag(i)
                    -- NOTE: If there is more than 26 projects, will stop there
                    if not f then
                        selection:text("Too much projects to display...")
                        break
                    end

                    selection:flag(f, project.content, {
                        callback = function()
                            selection:push_page()

                            module.private.create_recursive_project_placement(
                                selection,
                                project.node,
                                project.bufnr,
                                project.content,
                                task,
                                true
                            )
                        end,
                        destroy = false,
                    })
                end

                selection:blank():text("Create new project"):flag("x", "Create new project", {
                    callback = function()
                        selection:push_page()
                        selection:title("Create a new project"):blank():prompt("Project name", {
                            callback = function(text)
                                --- @type core.gtd.queries.project
                                local project = {}
                                project.content = text

                                selection:push_page()
                                selection
                                    :title("Create a new project")
                                    :blank()
                                    :text("Project name: " .. project.content)
                                    :blank()

                                local workspace = neorg.modules.get_module_config("core.gtd.base").workspace
                                local files = module.required["core.norg.dirman"].get_norg_files(workspace)

                                if vim.tbl_isempty(files) then
                                    selection:text("No files found...")
                                    return
                                end

                                selection:text("Select project location")
                                for i, file in pairs(files) do
                                    local f = module.private.create_flag(i)
                                    if not f then
                                        selection:title("Too much content...")
                                        break
                                    end
                                    selection:flag(f, file, {
                                        callback = function()
                                            module.private.create_project(selection, file, task, project)
                                        end,
                                        destroy = false,
                                    })
                                end
                            end,
                            pop = false,
                            destroy = false,
                        })
                    end,
                    destroy = false,
                })
            end,
            destroy = false,
        })
    end,

    create_project = function(selection, file, task, project)
        local tree = {
            {
                query = { "all", "marker" },
                recursive = true,
            },
        }

        local workspace = neorg.modules.get_module_config("core.gtd.base").workspace
        local path = module.required["core.norg.dirman"].get_workspace(workspace)
        local bufnr = module.required["core.norg.dirman"].get_file_bufnr(path .. "/" .. file)
        local nodes = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)
        local extracted_nodes = module.required["core.queries.native"].extract_nodes(nodes)

        local location
        if vim.tbl_isempty(nodes) then
            location = module.required["core.gtd.queries"].get_end_document_content(bufnr)
            if not location then
                log.error("Something is wrong in the " .. file .. " file")
                return
            end
            selection:destroy()
            module.required["core.gtd.queries"].create(
                "project",
                project,
                bufnr,
                { location, 0 },
                false,
                { newline = false }
            )
            module.required["core.gtd.queries"].create("task", task, bufnr, { location + 1, 2 }, false, {
                newline = false,
            })
        else
            selection:push_page()
            selection:title("Create a new project"):blank():text("Project name: " .. project.content):blank()
            selection:text("Select in which area of focus add this project")

            for i, marker_node in pairs(nodes) do
                local f = module.private.create_flag(i)
                if not f then
                    selection:title("Too much content...")
                    break
                end
                selection:flag(f, extracted_nodes[i]:sub(3), function()
                    local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
                    local _, _, er, _ = ts_utils.get_node_range(marker_node[1])
                    module.required["core.gtd.queries"].create(
                        "project",
                        project,
                        bufnr,
                        { er, 0 },
                        false,
                        { newline = false }
                    )
                    module.required["core.gtd.queries"].create("task", task, bufnr, { er + 1, 2 }, false, {
                        newline = false,
                    })
                end)
            end

            selection:flag("<CR>", "None", function()
                location = module.required["core.gtd.queries"].get_end_document_content(bufnr)
                if not location then
                    log.error("Something is wrong in the " .. file .. " file")
                    return
                end
                selection:destroy()

                module.required["core.gtd.queries"].create(
                    "project",
                    project,
                    bufnr,
                    { location, 0 },
                    true,
                    { newline = false }
                )
                module.required["core.gtd.queries"].create("task", task, bufnr, { location + 2, 2 }, false, {
                    newline = false,
                })
            end)
        end
    end,

    create_recursive_project_placement = function(selection, node, bufnr, project_title, task, is_project_root)
        ---- Creates flags for generic lists from current node
        --- @param _node core.gtd.queries.project
        local function get_generic_lists(_node, _bufnr)
            local tree = {
                { query = { "all", "generic_list" } },
                { query = { "all", "carryover_tag_set" } },
            }
            local nodes = module.required["core.queries.native"].query_from_tree(_node, tree, _bufnr)

            if nodes and not vim.tbl_isempty(nodes) then
                return nodes
            end
        end

        --- Recursively creates subheadings flags
        ---@param _node userdata
        local function create_subheadings(_selection, _node, _bufnr)
            local node_type = _node:type()
            -- Get subheading level
            local heading_level = string.sub(node_type, -1)
            heading_level = tonumber(heading_level) + 1

            -- Get all direct subheadings
            local tree = {
                {
                    query = { "all", "heading" .. heading_level },
                },
            }

            local nodes = module.required["core.queries.native"].query_from_tree(_node, tree, _bufnr)
            local extracted_nodes = module.required["core.queries.native"].extract_nodes(nodes)

            for i, n in pairs(extracted_nodes) do
                local f = module.private.create_flag(i)
                if not f then
                    _selection:title("Too much subheadings...")
                    break
                end
                n = string.sub(n, heading_level + 2)
                _selection:flag(f, "Append to " .. n .. " (subheading)", {
                    callback = function()
                        _selection:push_page()
                        module.private.create_recursive_project_placement(
                            _selection,
                            nodes[i][1],
                            nodes[i][2],
                            project_title,
                            task,
                            false
                        )
                    end,
                    destroy = false,
                })
            end
        end

        selection:title(project_title):blank()

        local description = is_project_root and "Project root" or "Root of current subheading"
        local location

        selection:text("Where do you want to add the task ?")
        create_subheadings(selection, node, bufnr)
        selection:flag("<CR>", description, {
            callback = function()
                local generic_lists = get_generic_lists(node, bufnr)
                if generic_lists then
                    local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

                    local last_list = generic_lists[#generic_lists]

                    local _, sc, er, _ = ts_utils.get_node_range(last_list[1])
                    if last_list[1]:type() == "carryover_tag_set" then
                        location = { er + 2, sc }
                    else
                        location = { er + 1, sc }
                    end
                else
                    location = module.required["core.gtd.queries"].get_end_project(node, bufnr)
                end

                module.required["core.gtd.queries"].create("task", task, bufnr, location, false, { newline = false })
                vim.cmd(string.format([[echom '%s']], 'Task added to "' .. project_title .. '".'))
            end,
            destroy = true,
        })
    end,

    create_flag = function(index)
        local alphabet = "abcdefghijklmnopqrstuvwxyz"
        index = (index % #alphabet)
        if index == 0 then
            return
        end

        return alphabet:sub(index, index)
    end,

    capture_task = function(selection)
        return selection:title("Add a task"):blank():prompt("Task", {
            callback = function(text)
                ---@type core.gtd.queries.task
                local task = {}
                task.content = text

                selection:push_page()

                selection
                    :title("Add informations")
                    :blank()
                    :text("Task: " .. task.content)
                    :blank()
                    :text("General informations")
                    :concat(function()
                        return module.private.generate_default_flags(selection, task, "contexts", "c")
                    end)
                    :concat(function()
                        return module.private.generate_default_flags(selection, task, "waiting.for", "w")
                    end)
                    :blank()
                    :text("Dates")
                    :concat(function()
                        return module.private.generate_date_flags(selection, task, "time.due", "d")
                    end)
                    :concat(function()
                        return module.private.generate_date_flags(selection, task, "time.start", "s")
                    end)
                    :blank()
                    :text("Insert")
                    :concat(function()
                        return module.private.generate_project_flags(selection, task, "p")
                    end)
                    :flag("x", "Add to cursor position", function()
                        local cursor = vim.api.nvim_win_get_cursor(0)
                        local location = { cursor[1] - 1, 0 }
                        module.required["core.gtd.queries"].create(
                            "task",
                            task,
                            0,
                            location,
                            false,
                            { newline = false }
                        )
                    end)
                    :flag("<CR>", "Add to inbox", function()
                        local inbox = neorg.modules.get_module_config("core.gtd.base").default_lists.inbox
                        local workspace = neorg.modules.get_module_config("core.gtd.base").workspace
                        local workspace_path = module.required["core.norg.dirman"].get_workspace(workspace)

                        local files = module.required["core.norg.dirman"].get_norg_files(workspace)
                        if not vim.tbl_contains(files, inbox) then
                            log.error([[ Inbox file is not from gtd workspace.
                            Please verify if the file exists in your gtd workspace.
                            Type :messages to show the full error report
                            ]])
                            return
                        end

                        local uri = vim.uri_from_fname(workspace_path .. "/" .. inbox)
                        local buf = vim.uri_to_bufnr(uri)
                        local end_row, projectAtEnd = module.required["core.gtd.queries"].get_end_document_content(buf)

                        module.required["core.gtd.queries"].create("task", task, buf, { end_row, 0 }, projectAtEnd)
                    end)

                return selection
            end,

            -- Do not pop or destroy the prompt when confirmed
            pop = false,
            destroy = false,
        })
    end,

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
