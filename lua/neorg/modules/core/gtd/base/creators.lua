local ts_utils = require("nvim-treesitter.ts_utils")

return function(module)
    return {
        --- Creates a new project from the `project` table and insert it in `file`
        --- @param project table
        ---   - project.content (string):         Mandatory field. It's the project name
        ---   - project.contexts (string[]):      Contexts names
        ---   - project.start (string):           Start date
        ---   - project.due (string):             Due date
        ---   - project.waiting_for (string[]):   Waiting For names
        --- @param file string
        create_project = function(project, file)
            local files = module.required["core.norg.dirman"].get_norg_files(module.config.public.workspace)
            if not vim.tbl_contains(files, file) then
                log.error("File " .. file .. " is not from gtd workspace")
                return
            end

            if vim.tbl_count(project) == 0 or not project.content then
                log.error("No project provided")
                return
            end

            local bufnr = module.private.get_bufnr_from_file(file)
            local tree = {
                { query = { "first", "document_content" } },
            }
            local document = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)[1]

            local _, _, end_col, _ = ts_utils.get_node_range(document[1])

            local res = {}

            table.insert(res, "")
            module.private.insert_content(res, project.contexts, "$contexts")
            module.private.insert_content(res, project.start, "$start")
            module.private.insert_content(res, project.due, "$due")
            module.private.insert_content(res, project.waiting_for, "$waiting.for")
            module.private.insert_content(res, project.content, "*")

            vim.api.nvim_buf_set_lines(bufnr, end_col, -1, false, res)
            vim.api.nvim_buf_call(bufnr, function()
                vim.cmd([[ write ]])
            end)
        end,

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
    }
end
