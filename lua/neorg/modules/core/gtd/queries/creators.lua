return function(module)
    return {
        public = {
            --- Creates a new project/task (depending of `type`) from the `node` table and insert it in `bufnr` at `location`
            --- supported `string`: project|task
            --- @param type string
            --- @param node table
            --- @param bufnr number
            --- @param location number
            ---   - project.content (string):         Mandatory field. It's the project name
            ---   - project.contexts (string[]):      Contexts names
            ---   - project.start (string):           Start date
            ---   - project.due (string):             Due date
            ---   - project.waiting_for (string[]):   Waiting For names
            --- @param delimit boolean #Add delimiter before the task/project if true
            create = function(type, node, bufnr, location, delimit)
                if not vim.tbl_contains({ "project", "task" }, type) then
                    log.error("You can only insert new project or task")
                    return
                end

                local res = {}

                if not node.content then
                    log.error("No node content provided")
                    return
                end

                table.insert(res, "")

                if delimit then
                    table.insert(res, "===")
                    table.insert(res, "")
                end

                module.private.insert_content(res, node.contexts, "$contexts")
                module.private.insert_content(res, node.start, "$start")
                module.private.insert_content(res, node.due, "$due")
                module.private.insert_content(res, node.waiting_for, "$waiting.for")
                module.private.insert_content(res, node.content, type == "project" and "*" or "- [ ]")

                vim.api.nvim_buf_set_lines(bufnr, location, location, false, res)
                vim.api.nvim_buf_call(bufnr, function()
                    vim.cmd([[ write ]])
                end)
            end,

            --- Returns the end of the `project`
            --- @param project table
            --- @return number
            get_end_project = function(project)
                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
                local _, _, end_row, _ = ts_utils.get_node_range(project.node)
                return end_row
            end,

            --- Returns the end of the document content position of a `file` and the `file` bufnr
            --- @param file string
            --- @return number, number, boolean
            get_end_document_content = function(file)
                local config = neorg.modules.get_module_config("core.gtd.base")
                local files = module.required["core.norg.dirman"].get_norg_files(config.workspace)
                if not vim.tbl_contains(files, file) then
                    log.error("File " .. file .. " is not from gtd workspace")
                    return
                end
                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

                local bufnr = module.private.get_bufnr_from_file(file)
                local tree = {
                    { query = { "first", "document_content" } },
                }
                local document = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)[1]

                local end_row
                local projectAtEnd = false

                -- There is no content in the document
                if not document then
                    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                    end_row = #lines
                else
                    -- Check if last child is a project
                    local nb_childs = document[1]:child_count()
                    local last_child = document[1]:child(nb_childs - 1)
                    if last_child:type() == "heading1" then
                        projectAtEnd = true
                    end

                    _, _, end_row, _ = ts_utils.get_node_range(document[1])
                end

                return end_row, bufnr, projectAtEnd
            end,
        },

        private = {
            --- Insert formatted `content` in `t`, with `prefix` before it. Mutates `t` !
            --- @param t table
            --- @param content string|table
            --- @param prefix string
            insert_content = function(t, content, prefix)
                if not content then
                    return
                end
                if type(content) == "string" then
                    table.insert(t, prefix .. " " .. content)
                elseif type(content) == "table" then
                    local inserted = prefix
                    for _, v in pairs(content) do
                        inserted = inserted .. " " .. v
                    end
                    table.insert(t, inserted)
                end
            end,
        },
    }
end


