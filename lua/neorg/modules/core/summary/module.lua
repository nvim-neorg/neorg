--[[
    file: Summary
    title: Write notes, not boilerplate.
    description: The summary module creates links and annotations to all files in a given workspace.
    summary: Creates links to all files in any workspace.
    ---
<!-- TODO: GIF -->
The `core.summary` module exposes a single command - `:Neorg generate-workspace-summary`.

When executed with the cursor hovering over a heading, `core.summary` will generate, you guessed it,
a summary of the entire workspace, with links to each respective entry in that workspace.

The way the summary is generated relies on the `strategy` configuration option,
which by default consults the document metadata (see also
[`core.esupports.metagen`](@core.esupports.metagen)) or the first heading title
as a fallback to build up a tree of categories, titles and descriptions.
--]]

local neorg = require("neorg.core")
local lib, utils = neorg.lib, neorg.utils

require("neorg.modules.base") -- TODO: Move to its own local core module
require("neorg.modules") -- TODO: Move to its own local core module

local module = neorg.modules.create("core.summary")

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
            name = "summary.summarize",
        },
    })

    local ts = module.required["core.integrations.treesitter"]

    module.config.public.strategy = lib.match(module.config.public.strategy)({
        default = function()
            -- declare query on load so that it's parsed once, on first use
            local heading_query

            local get_first_heading_title = function(bufnr)
                local document_root = ts.get_document_root(bufnr)
                if not heading_query then
                    -- allow second level headings, just in case
                    local heading_query_string = [[
                         [
                             (heading1
                                 title: (paragraph_segment) @next-segment
                             )
                             (heading2
                                 title: (paragraph_segment) @next-segment
                             )
                         ]
                     ]]
                    heading_query = utils.ts_parse_query("norg", heading_query_string)
                end
                -- search up to 20 lines (a doc could potentially have metadata without metadata.title)
                local _, heading = heading_query:iter_captures(document_root, bufnr)()
                if not heading then
                    return nil
                end
                local start_line, _ = heading:start()
                local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, start_line + 1, false)
                if #lines > 0 then
                    local title = lines[1]:gsub("^%s*%*+%s*", "") -- strip out '*' prefix (handle '* title', ' **title', etc)
                    if title ~= "" then -- exclude an empty heading like `*` (although the query should have excluded)
                        return title
                    end
                end
            end

            return function(files, ws_root, heading_level)
                local categories = vim.defaulttable()

                utils.read_files(files, function(bufnr, filename)
                    local metadata = ts.get_document_metadata(bufnr)

                    if not metadata then
                        metadata = {}
                    end

                    local norgname = filename:match("(.+)%.norg$") -- strip extension for link destinations
                    if not norgname then
                        norgname = filename
                    end
                    norgname = norgname:gsub("^" .. ws_root, "")

                    -- normalise categories into a list. Could be vim.NIL, a number, a string or a list ...
                    if not metadata.categories or metadata.categories == vim.NIL then
                        metadata.categories = { "Uncategorised" }
                    elseif not vim.tbl_islist(metadata.categories) then
                        metadata.categories = { tostring(metadata.categories) }
                    end
                    for _, category in ipairs(metadata.categories) do
                        if not metadata.title then
                            metadata.title = get_first_heading_title(bufnr)
                            if not metadata.title then
                                metadata.title = vim.fs.basename(norgname)
                            end
                        end
                        if metadata.description == vim.NIL then
                            metadata.description = nil
                        end
                        table.insert(categories[lib.title(category)], {
                            title = tostring(metadata.title),
                            norgname = norgname,
                            description = metadata.description,
                        })
                    end
                end)
                local result = {}
                local prefix = string.rep("*", heading_level)

                for category, data in vim.spairs(categories) do
                    table.insert(result, prefix .. " " .. category)

                    for _, datapoint in ipairs(data) do
                        table.insert(
                            result,
                            table.concat({
                                "   - {:$",
                                datapoint.norgname,
                                ":}[",
                                lib.title(datapoint.title),
                                "]",
                            })
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
    -- - "default" - read the metadata to categorize and annotate files. Files
    --   without metadata will use the top level heading as the title. If no headings are present, the filename will be used.
    ---@type string|fun(files: string[], ws_root: string, heading_level: number?): string[]?
    strategy = "default",
}

module.public = {}

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["summary.summarize"] = true,
    },
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.summary.summarize" then
        local ts = module.required["core.integrations.treesitter"]
        local buffer = event.buffer

        local node_at_cursor = ts.get_first_node_on_line(buffer, event.cursor_position[1] - 1)

        if not node_at_cursor or not node_at_cursor:type():match("^heading%d$") then
            utils.notify(
                "No heading under cursor! Please move your cursor under the heading you'd like to generate the summary under."
            )
            return
        end
        -- heading level of 'node_at_cursor' (summary headings should be one level deeper)
        local level = tonumber(string.sub(node_at_cursor:type(), -1))

        local dirman = neorg.modules.get_module("core.dirman")

        if not dirman then
            utils.notify("`core.dirman` is not loaded! It is required to generate summaries")
            return
        end

        local ws_root = dirman.get_current_workspace()[2]
        local generated = module.config.public.strategy(
            dirman.get_norg_files(dirman.get_current_workspace()[1]) or {},
            ws_root,
            level + 1
        )

        if not generated or vim.tbl_isempty(generated) then
            utils.notify(
                "No summary to generate! Either change the `strategy` option or ensure you have some indexable files in your workspace."
            )
            return
        end

        vim.api.nvim_buf_set_lines(buffer, event.cursor_position[1], event.cursor_position[1], true, generated)
    end
end

return module
