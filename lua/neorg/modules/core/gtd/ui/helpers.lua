--[[
    Helpers for gtd ui module and submodules
--]]
local module = neorg.modules.extend("core.gtd.ui.helpers", "core.gtd.ui")

---@class core.gtd.ui
module.public = {
    get_data_for_views = function()
        local exclude_files = module.required["core.gtd.helpers"].get_gtd_excluded_files()

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

--- @class private_core.gtd.ui
module.private = {
    --- Try to re-fetch the node with newer content (after an update for example)
    --- @param node table
    --- @param type string
    --- @return core.gtd.queries.task|core.gtd.queries.project
    refetch_data_not_extracted = function(node, type)
        -- Get all nodes from the bufnr and add metadatas to it
        -- This is mandatory because we need to have the correct task position, else the update will not work
        local nodes = module.required["core.gtd.queries"].get(type .. "s", { bufnr = node[2] })
        --- @type core.gtd.queries.task[]|core.gtd.queries.project[]
        nodes = module.required["core.gtd.queries"].add_metadata(nodes, type, { extract = false, same_node = true })

        -- Find the correct task node
        local found_data = vim.tbl_filter(function(n)
            return n.internal.node:id() == node[1]:id()
        end, nodes)

        if #found_data == 0 then
            log.error("Error in fetching " .. type)
            return
        end

        return found_data[1]
    end,
}

return module
