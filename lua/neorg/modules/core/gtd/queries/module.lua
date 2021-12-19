--[[
    File: GTD-Queries
    Title: GTD Queries module
    Summary: Gets tasks, projects and useful information for the GTD system.
    ---

Custom gtd queries, that respect the neorg GTD specs (`:h neorg-gtd-format`)
--]]

require("neorg.modules.base")
local module = neorg.modules.create("core.gtd.queries")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.queries.native",
            "core.integrations.treesitter",
        },
        imports = {
            "helpers",
            "retrievers",
            "creators",
            "modifiers",
        },
    }
end

module.examples = {
    ["Get all tasks and projets from buffer"] = function()
        local buf = 1 -- The buffer to query informations

        local queries = module.required["core.gtd.queries"]

        local tasks = queries.get("tasks", { bufnr = buf })
        local projects = queries.get("projects", { bufnr = buf })

        print(tasks, projects)
    end,
}

module.public = {
    version = "0.0.8",
}

module.private = {
    temp_bufs = {},

    get_temp_buf = function(buffer)
        if not module.private.temp_bufs[buffer] then
            local buf = vim.api.nvim_create_buf(false, true)
            local text = module.required["core.queries.native"].get_file_text(buffer)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n"))
            module.private.temp_bufs[buffer] = buf
        end
        return module.private.temp_bufs[buffer]
    end,

    delete_temp_buf = function(buffer)
        if buffer and module.private.temp_bufs[buffer] then
            vim.api.nvim_buf_delete(buffer, { force = true })
            module.private.temp_bufs[buffer] = nil
            return
        end

        if not buffer then
            for _, buf in pairs(module.private.temp_bufs) do
                vim.api.nvim_buf_delete(buf, { force = true })
                module.private.temp_bufs[buf] = nil
            end
        end
    end,
}

return module
