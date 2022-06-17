--[[
    Submodule responsible for creating API for gtd edit
--]]

local module = neorg.modules.extend("core.gtd.ui.edit_popup", "core.gtd.ui")

---@class core.gtd.ui
module.public = {
    --- Called when doing `:Neorg gtd edit`
    --- Will try to find a task at cursor position to edit
    edit_task_at_cursor = function()
        -- Reset state of previous fetches
        module.required["core.queries.native"].delete_content()

        local task_node = module.required["core.gtd.queries"].get_at_cursor("task")

        if not task_node then
            log.warn("No task at cursor position")
            return
        end

        local task = module.private.refetch_data_not_extracted(task_node, "task")

        module.public.edit_task(task)
    end,

    --- Creates the gtd edit popup
    ---@param task core.gtd.queries.task
    edit_task = function(task)
        -- Add metadatas to task node
        local task_extracted = module.required["core.gtd.queries"].add_metadata(
            { { task.internal.node, task.internal.bufnr } },
            "task",
            { same_node = true, extract = true }
        )[1]

        local modified = {}

        -- Create selection popup
        local buffer = module.required["core.ui"].create_split("Edit Task")

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

        selection:title("Edit Task"):blank():text("Task: " .. task_extracted.content)
        if task_extracted.contexts then
            selection:text("Contexts: " .. table.concat(task_extracted.contexts, ", "))
        end
        if task_extracted["waiting.for"] then
            selection:text("Waiting for: " .. table.concat(task_extracted["waiting.for"], ", "))
        end
        if task_extracted["time.start"] then
            selection:text("Starting: " .. task_extracted["time.start"][1])
        end
        if task_extracted["time.due"] then
            selection:text("Due for: " .. task_extracted["time.due"][1])
        end

        selection
            :blank()
            :concat(function()
                return module.private.edit_prompt(
                    selection,
                    "e",
                    "Edit content",
                    "content",
                    modified,
                    { prompt_title = "Edit Content", prompt_text = task_extracted["content"] }
                )
            end)
            :blank()
            :text("General Metadatas")
            :concat(function()
                return module.private.edit(
                    selection,
                    "c",
                    { edit = "Edit contexts", delete = "Delete contexts" },
                    modified,
                    "contexts",
                    task_extracted
                )
            end)
            :concat(function()
                return module.private.edit(
                    selection,
                    "w",
                    { edit = "Edit waiting fors", delete = "Delete waiting fors" },
                    modified,
                    "waiting.for",
                    task_extracted
                )
            end)
            :blank()
            :text("Due/Start dates")
            :concat(function()
                return module.private.edit_date(selection, "s", {
                    title = "Reschedule or remove start date",
                    edit = "Reschedule date",
                    delete = "Remove start date",
                }, modified, "time.start", task)
            end)
            :concat(function()
                return module.private.edit_date(selection, "d", {
                    title = "Reschedule or remove due date",
                    edit = "Reschedule date",
                    delete = "Remove due date",
                }, modified, "time.due", task)
            end)

        selection:blank(2):flag("<CR>", "Validate", function()
            local data = selection:data()

            local edits = { "contexts", "waiting.for", "content", "time.start", "time.due" }

            for _, k in pairs(edits) do
                if data["delete_" .. k] then
                    task = module.required["core.gtd.queries"].delete(task, "task", k)
                else
                    task = module.required["core.gtd.queries"].modify(task, "task", k, modified[k], { tag = "#" .. k })
                end
            end

            module.required["core.queries.native"].apply_temp_changes(task.internal.bufnr)
        end)

        module.public.display_messages()
    end,
}

--- @class private_core.gtd.ui
module.private = {
    --- Edit content from `key`.
    ---@param selection core.ui.selection
    ---@param flag string #The flag to use for calling the prompt
    ---@param text string #The text to show for the flag
    ---@param key string #The key to modify
    ---@param modified table #The table to insert modified text
    ---@param opts table
    ---   - opts.multiple_texts (bool):     if true, will split the modified content and convert into a list
    ---   - opts.pop_page (bool):           if true, will pop the page a second time
    ---   - opts.prompt_title (string):     provide custom prompt title. Else defaults to "Edit"
    ---   - opts.prompt_text (string):      provide custom text, if any
    ---@return table #The selection
    edit_prompt = function(selection, flag, text, key, modified, opts)
        opts = opts or {}
        local prompt_title = opts.prompt_title or "Edit"

        selection = selection:flag(flag, text, {
            destroy = false,
            callback = function()
                selection:push_page()
                selection:title(prompt_title):blank():prompt(prompt_title, {
                    callback = function(t)
                        if #t > 0 then
                            if opts.multiple_texts then
                                modified[key] = vim.split(t, " ", true)
                            else
                                modified[key] = t
                            end
                        end
                        -- We don't delete the key at CR because we just modified it
                        selection:set_data("delete_contexts", false)

                        if opts.pop_page then
                            selection:pop_page()
                        end
                    end,
                    pop = true,
                    prompt_text = opts.prompt_text,
                })
            end,
        })
        return selection
    end,

    --- Generates subflags for edit popup
    ---@param selection core.ui.selection
    ---@param flag string
    ---@param texts table
    ---@param modified boolean
    ---@param key string
    ---@param task core.gtd.queries.task
    ---@return core.ui.selection
    edit = function(selection, flag, texts, modified, key, task)
        selection = selection:rflag(flag, texts.edit, function()
            selection = selection
                :text(texts.edit)
                :blank()
                :concat(function()
                    selection = module.private.edit_prompt(selection, "e", texts.edit, key, modified, {
                        prompt_title = texts.edit,
                        pop_page = true,
                        multiple_texts = true,
                        prompt_text = type(task[key]) == "table" and table.concat(task[key], " "),
                    })
                    return selection
                end)
                :flag("d", texts.delete, {
                    destroy = false,
                    callback = function()
                        if not task[key] then
                            log.warn("Nothing to delete")
                        else
                            selection:set_data("delete_" .. key, true)
                        end
                        selection:pop_page()
                    end,
                })

            return selection
        end)
        return selection
    end,

    --- Subflags for edition of dates
    ---@param selection core.ui.selection
    ---@param flag string
    ---@param texts table
    ---@param modified boolean
    ---@param key string
    ---@param task core.gtd.queries.task
    ---@return core.ui.selection
    edit_date = function(selection, flag, texts, modified, key, task)
        selection = selection:rflag(flag, texts.title, function()
            selection = selection
                :text(texts.title)
                :blank()
                :flag("t", "Reschedule for tomorrow", {
                    destroy = false,
                    callback = function()
                        modified[key] = module.required["core.gtd.queries"].date_converter("tomorrow")
                        selection:pop_page()
                    end,
                })
                :flag("c", "Custom", {
                    destroy = false,
                    callback = function()
                        selection:push_page()
                        selection
                            :title("Custom Date")
                            :text("Allowed date format: today, tomorrow, Xw, Xd, Xm, Xy (X is a number)")
                            :text("You can even use 'mon', 'tue', 'wed' ... for the next weekday date")
                            :text("You can also use '2mon' for the 2nd monday that will come")
                            :blank()
                            :prompt("Enter date", {
                                callback = function(text)
                                    if #text > 0 then
                                        modified[key] = module.required["core.gtd.queries"].date_converter(text)
                                        if not modified[key] then
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
                :blank()
                :flag("d", texts.delete, {
                    destroy = false,
                    callback = function()
                        if not task[key] then
                            log.warn("Nothing to delete")
                        else
                            selection:set_data("delete_" .. key, true)
                        end
                        selection:pop_page()
                    end,
                })
        end)
        return selection
    end,
}

return module
