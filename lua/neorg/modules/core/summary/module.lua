--[[
    DIRMAN SUMMARY
    module to generate a summary of a workspace inside a note
--]]

require("neorg.modules.base")
require("neorg.modules")
require("neorg.external.helpers")

local module = neorg.modules.create("core.norg.dirman.summary")

module.setup = function()
    return {
        sucess = true,
        requires = { "core.neorgcmd", "core.integrations.treesitter" },
    }
end

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        ["generate-workspace-summary"] = {
            args = 0,
            condition = "norg",
            name = "dirman.summary",
        },
    })

    local ts = module.required["core.integrations.treesitter"]

    module.config.public.strategy = neorg.lib.match(module.config.public.strategy)({
        metadata = function()
            return function(files)
                local categories = vim.defaulttable()

                neorg.utils.read_files(files, function(bufnr, filename)
                    local metadata = ts.get_document_metadata(bufnr)

                    if not metadata or vim.tbl_isempty(metadata) then
                        return
                    end

                    for _, category in
                        ipairs(vim.tbl_islist(metadata.categories) and metadata.categories or { metadata.categories })
                    do
                        if metadata.title then
                            table.insert(
                                categories[category],
                                { title = metadata.title, filename = filename, description = metadata.description }
                            )
                        end
                    end
                end)

                local result = {}

                for category, data in vim.spairs(categories) do
                    table.insert(result, "** " .. neorg.lib.title(category))

                    for _, datapoint in ipairs(data) do
                        table.insert(
                            result,
                            table.concat({ "- {:", datapoint.filename, ":}[", neorg.lib.title(datapoint.title), "]" })
                                .. (datapoint.description and (table.concat({ " - ", datapoint.description })) or "")
                        )
                    end
                end

                return result
            end
        end,
        headings = function()
            return function() end
        end,
    }) or module.config.public.strategy
end

module.config.public = {
    -- The strategy to use to generate a summary.
    --
    -- Possible options are:
    -- - "metadata" - read the metadata to categorize and annotate files. Files
    --   without metadata will be ignored.
    -- - "headings" (UNIMPLEMENTED) - read the top level heading and use that as the title.
    --   files in subdirectories are treated as subheadings.
    ---@type string|fun(files: string[]): string[]?
    strategy = "metadata",
}

module.public = {}

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["dirman.summary"] = true,
    },
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.dirman.summary" then
        local ts = module.required["core.integrations.treesitter"]
        local buffer = event.buffer

        local node_at_cursor = ts.get_first_node_on_line(buffer, event.cursor_position[1] - 1)

        if not node_at_cursor or not node_at_cursor:type():match("^heading%d$") then
            vim.notify(
                "No heading under cursor! Please move your cursor under the heading you'd like to generate the summary under."
            )
            return
        end

        local dirman = neorg.modules.get_module("core.norg.dirman")

        if not dirman then
            vim.notify("`core.norg.dirman` is not loaded! It is required to generate summaries")
            return
        end

        local generated = module.config.public.strategy(dirman.get_norg_files(dirman.get_current_workspace()[1]) or {})

        if not generated or vim.tbl_isempty(generated) then
            vim.notify(
                "No summary to generate! Either change the `strategy` option or ensure you have some indexable files in your workspace."
            )
            return
        end

        vim.api.nvim_buf_set_lines(buffer, event.cursor_position[1], event.cursor_position[1], true, generated)
    end
end

return module
