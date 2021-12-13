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

return module
