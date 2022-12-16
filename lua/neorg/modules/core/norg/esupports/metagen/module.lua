--[[
    File: Metagen
    Title: Generate Neorg metadata
    Summary: A Neorg module for generating document metadata automatically.
    ---
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.esupports.metagen")

module.setup = function()
    return { requires = { "core.autocommands", "core.keybinds", "core.integrations.treesitter" } }
end

module.config.public = {
    -- One of "none", "auto" or "empty"
    -- - None generates no metadata
    -- - Auto generates metadata if it is not present
    -- - Empty generates metadata only for new files/buffers.
    type = "none",

    -- Whether updated date field should be automatically updated on save if required
    update_date = true,

    -- How to generate a tabulation inside the `@document.meta` tag
    tab = "",

    -- Custom delimiter between tag and value
    delimiter = ": ",

    -- Custom template to use for generating content inside `@document.meta` tag
    template = {
        {
            "title",
            function()
                return vim.fn.expand("%:p:t:r")
            end,
        },
        { "description", "" },
        { "authors", require("neorg.external.helpers").get_username },
        { "categories", "" },
        {
            "created",
            function()
                return os.date("%Y-%m-%d")
            end,
        },
        {
            "updated",
            function()
                return os.date("%Y-%m-%d")
            end,
        },
        { "version", require("neorg.config").version },
    },
}

module.private = {
    buffers = {},
    listen_event = "none",
}

---@class core.norg.esupports.metagen
module.public = {
    --- Returns true if there is a `@document.meta` tag in the current document
    ---@param buf number #The buffer to check in
    ---@return boolean,table #Whether the metadata was present, and the range of the metadata node
    is_metadata_present = function(buf)
        local query = vim.treesitter.parse_query(
            "norg",
            [[
                 (ranged_tag
                     (tag_name) @name
                     (#eq? @name "document.meta")
                 ) @meta
            ]]
        )

        local root = module.required["core.integrations.treesitter"].get_document_root(buf)

        if not root then
            return false, { 0, 0 }
        end

        local _, found = query:iter_matches(root, buf)()
        local range = { 0, 0 }

        if not found then
            return false, range
        end

        for id, node in pairs(found) do
            local name = query.captures[id]
            if name == "meta" then
                range[1], _, range[2], _ = node:range()
                range[2] = range[2] + 2
            end
        end

        return true, range
    end,

    --- Creates the metadata contents from the configuration's template.
    ---@param buf number #The buffer to query potential data from
    ---@return table #A table of strings that can be directly piped to `nvim_buf_set_lines`
    construct_metadata = function(buf)
        local template = module.config.public.template
        local whitespace = type(module.config.public.tab) == "function" and module.config.public.tab()
            or module.config.public.tab
        local delimiter = type(module.config.public.delimiter) == "function" and module.config.public.delimiter()
            or module.config.public.delimiter

        local result = {
            "@document.meta",
        }

        for _, data in ipairs(template) do
            table.insert(
                result,
                whitespace .. data[1] .. delimiter .. tostring(type(data[2]) == "function" and data[2]() or data[2])
            )
        end

        table.insert(result, "@end")

        if vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]:len() > 0 then
            table.insert(result, "")
        end

        return result
    end,

    --- Inject the metadata into a buffer
    ---@param buf number #The number of the buffer to inject the metadata into
    ---@param force? boolean #Whether to forcefully override existing metadata
    inject_metadata = function(buf, force)
        local present, range = module.public.is_metadata_present(buf)
        if force or not present then
            local constructed_metadata = module.public.construct_metadata(buf)
            vim.api.nvim_buf_set_lines(buf, range[1], range[2], false, constructed_metadata)
        end
    end,

    update_metadata = function(buf)
        local present, range = module.public.is_metadata_present(buf)
        if present then
            local current_date = os.date("%Y-%m-%d")
            local meta = vim.api.nvim_buf_get_lines(buf, range[1], range[2], false)
            for idx, field in ipairs(meta) do
                local updated_field = field:match("updated: %d+%-%d+%-%d+")
                if updated_field then
                    local updated_date = updated_field:match("%d+%-%d+-%d+")
                    if updated_date ~= current_date then
                        local new_date = updated_field:gsub("%d+%-%d+-%d+", current_date)
                        vim.api.nvim_buf_set_lines(buf, idx - 1, idx, false, { new_date })
                    end
                end
            end
        end
    end,
}

module.load = function()
    neorg.modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            ["inject-metadata"] = {
                args = 0,
                name = "inject-metadata",
                condition = "norg",
            },
            ["update-metadata"] = {
                args = 0,
                name = "update-metadata",
                condition = "norg",
            },
        })
    end)

    if module.config.public.type == "auto" then
        module.required["core.autocommands"].enable_autocommand("BufEnter")
        module.private.listen_event = "bufenter"
    elseif module.config.public.type == "empty" then
        module.required["core.autocommands"].enable_autocommand("BufNewFile")
        module.private.listen_event = "bufnewfile"
    end

    if module.config.public.update_date then
        vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*.norg",
            callback = function()
                module.public.update_metadata(vim.api.nvim_get_current_buf())
            end,
            desc = "Update updated date metadata field in norg documents",
        })
    end
end

module.on_event = function(event)
    if
        event.type == ("core.autocommands.events." .. module.private.listen_event)
        and event.content.norg
        and vim.api.nvim_buf_is_loaded(event.buffer)
        and vim.api.nvim_buf_get_option(event.buffer, "modifiable")
        and not module.private.buffers[event.buffer]
        and not vim.startswith(event.filehead, "neorg://") -- Do not inject metadata on displays created by neorg by default
    then
        module.public.inject_metadata(event.buffer)
        module.private.buffers[event.buffer] = true
    elseif event.type == "core.neorgcmd.events.inject-metadata" then
        module.public.inject_metadata(event.buffer, true)
        module.private.buffers[event.buffer] = true
    elseif event.type == "core.neorgcmd.events.update-metadata" then
        module.public.update_metadata(event.buffer)
        module.private.buffers[event.buffer] = true
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
        bufnewfile = true,
        bufwritepre = true,
    },

    ["core.neorgcmd"] = {
        ["inject-metadata"] = true,
        ["update-metadata"] = true,
    },
}

return module
