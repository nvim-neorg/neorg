--[[
    File: GTD-helpers
    Title: GTD Helpers module
    Summary: Nice helpers for GTD modules.
    Internal: true
    ---

This module is a set of public functions designed to ease GTD development.
--]]
require("neorg.modules.base")

local module = neorg.modules.create("core.gtd.helpers")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
        },
    }
end

---@class core.gtd.helpers
module.public = {
    version = "0.0.9",

    --- Returns the list of every used file for GTD
    get_gtd_files = function(opts)
        opts = opts or {}
        local gtd_config = module.private.get_gtd_config()

        local ws = gtd_config.workspace
        local files = module.required["core.norg.dirman"].get_norg_files(ws)

        if vim.tbl_isempty(files) then
            return
        end

        if opts.no_exclude then
            return files
        end

        local excluded_files = module.public.get_gtd_excluded_files()
        for _, excluded_file in pairs(excluded_files) do
            files = module.private.remove_from_table(files, excluded_file)
        end

        return files
    end,

    --- Returns the list of every excluded file in gtd
    ---@return table
    get_gtd_excluded_files = function()
        local gtd_config = module.private.get_gtd_config()
        local res = vim.deepcopy(gtd_config.exclude) or {}

        return res
    end,

    --- Checks if the data is processed or not.
    --- Check out :h neorg-gtd to know what is an unclarified task or project
    ---@param data core.gtd.queries.task|core.gtd.queries.project
    ---@param extra core.gtd.queries.task[]?|core.gtd.queries.project[]
    is_processed = function(data, extra)
        return neorg.lib.match(data.type)({
            ["task"] = function()
                -- Processed task if:
                --   - Not in inbox
                --   - Has a due context or waiting for
                if not data.inbox then
                    if type(data["time.due"]) == "table" and not vim.tbl_isempty(data["time.due"]) then
                        return true
                    elseif type(data["waiting.for"]) == "table" and not vim.tbl_isempty(data["waiting.for"]) then
                        return true
                    end
                end

                -- Processed task if:
                --   - Has a due date or start date
                --   - Is in "someday"
                if type(data["time.due"]) == "table" and not vim.tbl_isempty(data["time.due"]) then
                    return true
                elseif type(data["time.start"]) == "table" and not vim.tbl_isempty(data["time.start"]) then
                    return true
                elseif type(data["contexts"]) == "table" and not vim.tbl_isempty(data["contexts"]) then
                    return true
                end

                if not extra then
                    return false
                end

                local project = vim.tbl_filter(function(t)
                    return t.uuid == data.project_uuid
                end, extra)

                if not vim.tbl_isempty(project) then
                    project = project[1]
                    if type(project["contexts"]) == "table" and not vim.tbl_isempty(project["contexts"]) then
                        return true
                    end
                end

                return false
            end,
            ["project"] = function()
                if not extra then
                    return
                end

                -- If the project is in someday, do not count it as unprocessed
                if
                    type(data.contexts) == "table"
                    and not vim.tbl_isempty(data.contexts)
                    and vim.tbl_contains(data.contexts, "someday")
                then
                    return true
                end

                -- All projects in inbox are unprocessed
                if data.inbox then
                    return false
                end

                local project_tasks = vim.tbl_filter(function(t)
                    return t.project_uuid == data.uuid
                end, extra)

                -- Empty projects (without tasks) are unprocessed
                if vim.tbl_isempty(project_tasks) then
                    return false
                end

                -- Do not count done tasks for unprocessed projects
                project_tasks = vim.tbl_filter(function(t)
                    return t.state ~= "done"
                end, project_tasks)

                return not vim.tbl_isempty(project_tasks)
            end,
        })
    end,

    --- Converts a task state (e.g: "undone") to its norg equivalent (e.g: "- [ ]")
    ---@param state string
    ---@return string
    state_to_text = function(state)
        return neorg.lib.match(state)({
            done = "- [x]",
            undone = "- [ ]",
            pending = "- [-]",
            uncertain = "- [?]",
            urgent = "- [!]",
            recurring = "- [+]",
            on_hold = "- [=]",
            cancelled = "- [_]",
        })
    end,
}

module.private = {
    --- Convenience wrapper to set type for gtd_config
    ---@return core.gtd.base.config
    get_gtd_config = function()
        return neorg.modules.get_module_config("core.gtd.base")
    end,

    --- Remove `el` from table `t`
    ---@param t table
    ---@param el any
    ---@return table
    remove_from_table = function(t, el)
        vim.validate({ t = { t, "table" } })
        local result = {}

        -- This is possibly a directory, so we remove every file inside this directory
        if not vim.endswith(el, ".norg") then
            for _, v in ipairs(t) do
                if not vim.startswith(v, el) then
                    table.insert(result, v)
                end
            end
        else
            for _, v in ipairs(t) do
                if v ~= el then
                    table.insert(result, v)
                end
            end
        end

        return result
    end,
}

return module
