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

                -- Inserts the content and insert the tags just after
                node.node = module.private.insert_content_new(node.content, bufnr, location, type, { newline = true })

                module.public.insert_tag({ node.node, bufnr }, node.contexts, "$contexts")
                module.public.insert_tag({ node.node, bufnr }, node.start, "$start")
                module.public.insert_tag({ node.node, bufnr }, node.due, "$due")
                module.public.insert_tag({ node.node, bufnr }, node.waiting_for, "$waiting_for")

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

            --- Insert the tag above a `type`
            --- @param node table #Must be { node, bufnr }
            --- @param content string|table
            --- @param prefix string
            --- @return boolean #Whether inserting succeeded (if so, save the file)
            insert_tag = function(node, content, prefix)
                if not content then
                    return
                end
                local inserter = {}
                module.private.insert_content(inserter, content, prefix)

                local parent_tag_set = module.required["core.queries.native"].find_parent_node(
                    node,
                    "carryover_tag_set"
                )

                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

                local node_line, _, _, _ = ts_utils.get_node_range(node[1])
                if #parent_tag_set == 0 then
                    -- No tag created, i will insert the tag just before the node
                    vim.api.nvim_buf_set_lines(node[2], node_line, node_line, false, inserter)
                    return true
                else
                    -- Gets the last tag in the found tag_set
                    local tags_number = parent_tag_set[1]:child_count()
                    local last_tag = parent_tag_set[1]:child(tags_number - 1)

                    -- Check if the last tag in the tag_set is just above the `node`. If so, inserts the tag before the node
                    local start_row, _, _, _ = ts_utils.get_node_range(last_tag)
                    if start_row == node_line - 1 then
                        vim.api.nvim_buf_set_lines(node[2], node_line, node_line, false, inserter)
                        return true
                    end
                end
            end,

            --- Returns a random uuid
            --- @return string
            -- @see https://gist.github.com/jrus/3197011
            generate_uuid = function()
                local random = math.random
                local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
                return string.gsub(template, '[xy]', function (c)
                    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
                    return string.format('%x', v)
                end)
            end,

            --- Search for all $uuid tags and generate missing UUIDs for each node
            --- @param nodes table #A table of { node, bufnr }
            generate_missing_uuids = function (nodes)
                -- TODO: find a better way to save
                for _, node in pairs(nodes) do
                    local task_extracted = module.public.add_metadata({ node }, "task")[1]

                    local uuid = module.public.generate_uuid()
                    local carryover_tag_set = module.required["core.queries.native"].find_parent_node( node, "carryover_tag_set")

                    if #carryover_tag_set == 0 then
                        module.public.insert_tag(node,uuid, "$uuid")
                        --vim.api.nvim_buf_call(node[2], function()
                            --vim.cmd(" write ")
                        --end)
                        -- Re-get all tasks on current buffer
                        local nodes = module.public.get("tasks", { bufnr = node[2] })
                        module.public.generate_missing_uuids(nodes)
                        return

                    end

                end
            end,
        },

        private = {
            --- Insert a `content` (with specific `type`) at specified `location`
            --- @param content string
            --- @param bufnr number
            --- @param location number
            --- @param type string #project|task
            --- @param opts table
            ---   - opts.newline (bool):    is true, insert a newline before the content
            --- @return userdata|nil #the newly created node. Else returns nil
            insert_content_new = function(content, bufnr, location, type, opts)
                local inserter = {}
                local prefix = type == "project" and "* " or "- [ ] "

                if opts.newline then
                    table.insert(inserter, "")
                end

                table.insert(inserter, prefix .. content)

                vim.api.nvim_buf_set_lines(bufnr, location, location, false, inserter)

                -- Get all nodes for `type` and return the one that is present at `location`
                local nodes = module.public.get(type .. "s", { bufnr = bufnr })
                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

                for _, node in pairs(nodes) do
                    local line = ts_utils.get_node_range(node[1])

                    local count_newline = opts.newline and 1 or 0
                    if line == location + count_newline then
                        return node[1]
                    end
                end
            end,
        },
    }
end
