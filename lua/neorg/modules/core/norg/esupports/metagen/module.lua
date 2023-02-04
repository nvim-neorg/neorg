--[[
    file: Metagen
    title: Manually Writing Metadata? No Thanks
    description: The metagen module automatically places relevant metadata at the top of your `.norg` files.
    summary: A Neorg module for generating document metadata automatically.
    ---
The metagen module exposes two commands - `:Neorg inject-metadata` and `:Neorg update-metadata`.

- The `inject-metadata` command will remove any existing metadata and overwrite it with fresh information.
- The `update-metadata` preserves existing info, updating things like the `updated` fields (when the file
  was last edited) as well as a few other non-destructive fields.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.esupports.metagen")

module.setup = function()
    return { requires = { "core.autocommands", "core.keybinds", "core.integrations.treesitter" } }
end

module.config.public = {
    -- One of "none", "auto" or "empty"
    -- - "none" generates no metadata
    -- - "auto" generates metadata if it is not present
    -- - "empty" generates metadata only for new files/buffers.
    type = "none",

    -- Whether updated date field should be automatically updated on save if required
    update_date = true,

    -- How to generate a tabulation inside the `@document.meta` tag
    tab = "",

    -- Custom delimiter between tag and value
    delimiter = ": ",

    -- Custom template to use for generating content inside `@document.meta` tag
    template = {
        -- The title field generates a title for the file based on the filename.
        {
            "title",
            function()
                return vim.fn.expand("%:p:t:r")
            end,
        },

        -- The description field is always kept empty for the user to fill in.
        { "description", "" },

        -- The authors field is autopopulated by querying the current user's system username.
        { "authors", require("neorg.external.helpers").get_username },

        -- The categories field is always kept empty for the user to fill in.
        { "categories", "" },

        -- The created field is populated with the current date as returned by `os.date`.
        {
            "created",
            function()
                return os.date("%Y-%m-%d")
            end,
        },

        -- When creating fresh, new metadata, the updated field is populated the same way
        -- as the `created` date.
        {
            "updated",
            function()
                return os.date("%Y-%m-%d")
            end,
        },

        -- The version field determines which Norg version was used when
        -- the file was created.
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
                 (ranged_verbatim_tag
                     (tag_name) @name
                     (#eq? @name "document.meta")
                 ) @meta
            ]]
        )

        local root = module.required["core.integrations.treesitter"].get_document_root(buf)

        if not root then
            return false, {
                range = { 0, 0 },
                node = nil,
            }
        end

        local _, found = query:iter_matches(root, buf)()
        local range = { 0, 0 }

        if not found then
            return false, {
                range = range,
                node = nil,
            }
        end

        local metadata_node = nil

        for id, node in pairs(found) do
            local name = query.captures[id]
            if name == "meta" then
                metadata_node = node
                range[1], _, range[2], _ = node:range()
                range[2] = range[2] + 2
            end
        end

        return true, {
            range = range,
            node = metadata_node,
        }
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
        local present, data = module.public.is_metadata_present(buf)

        if force or not present then
            local constructed_metadata = module.public.construct_metadata(buf)
            vim.api.nvim_buf_set_lines(buf, data.range[1], data.range[2], false, constructed_metadata)
        end
    end,

    update_metadata = function(buf)
        local present = module.public.is_metadata_present(buf)

        if not present then
            return
        end

        -- Extract the root node of the norg_meta language
        -- This process should be abstracted into a core.integrations.treesitter
        -- function.
        local languagetree = vim.treesitter.get_parser(buf, "norg")

        if not languagetree then
            return
        end

        local meta_root = nil

        languagetree:for_each_child(function(tree)
            if tree:lang() ~= "norg_meta" or meta_root then
                return
            end

            local meta_tree = tree:parse()[1]

            if not meta_tree then
                return
            end

            meta_root = meta_tree:root()
        end)

        if not meta_root then
            return
        end

        local current_date = os.date("%Y-%m-%d")

        local query = vim.treesitter.parse_query(
            "norg_meta",
            [[
            (pair
                (key) @_key
                (#eq? @_key "updated")
                (value) @updated)
        ]]
        )

        for id, node in query:iter_captures(meta_root, buf) do
            local capture = query.captures[id]

            if capture == "updated" then
                local date = module.required["core.integrations.treesitter"].get_node_text(node)

                if date ~= current_date then
                    local range = module.required["core.integrations.treesitter"].get_node_range(node)

                    vim.api.nvim_buf_set_text(
                        buf,
                        range.row_start,
                        range.column_start,
                        range.row_end,
                        range.column_end,
                        { current_date }
                    )
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
