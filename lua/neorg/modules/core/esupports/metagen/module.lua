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

local neorg = require("neorg.core")
local config, modules, utils, lib = neorg.config, neorg.modules, neorg.utils, neorg.lib

local module = modules.create("core.esupports.metagen")

local function get_timezone_offset()
    -- http://lua-users.org/wiki/TimeZon
    -- return the timezone offset in seconds, as it was on the time given by ts
    -- Eric Feliksik
    local utcdate = os.date("!*t", 0)
    local localdate = os.date("*t", 0)
    localdate.isdst = false -- this is the trick
    return os.difftime(os.time(localdate), os.time(utcdate)) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
end

local function get_timestamp()
    -- generate a ISO-8601 timestamp
    -- example: 2023-09-05T09:09:11-0500
    --
    local timezone_config = module.config.public.timezone
    if timezone_config == "utc" then
        return os.date("!%Y-%m-%dT%H:%M:%S+0000")
    elseif timezone_config == "implicit-local" then
        return os.date("%Y-%m-%dT%H:%M:%S")
    else
        -- assert(timezone_config == "local")
        local tz_offset = get_timezone_offset()
        local h, m = math.modf(tz_offset / 3600)
        return os.date("%Y-%m-%dT%H:%M:%S") .. string.format("%+.4d", h * 100 + m * 60)
    end
end

local function get_author()
    local author_config = module.config.public.author

    if author_config == nil or author_config == "" then
        return utils.get_username()
    else
        return author_config
    end
end

-- The default template found in the config for this module.
local default_template = {
    -- The title field generates a title for the file based on the filename.
    {
        "title",
        function()
            return vim.fn.expand("%:p:t:r")
        end,
    },

    -- The description field is always kept empty for the user to fill in.
    { "description", "" },

    -- The authors field is taken from config or autopopulated by querying the current user's system username.
    {
        "authors",
        get_author,
    },

    -- The categories field is always kept empty for the user to fill in.
    { "categories", "" },

    -- The created field is populated with the current date as returned by `os.date`.
    {
        "created",
        get_timestamp,
    },

    -- When creating fresh, new metadata, the updated field is populated the same way
    -- as the `created` date.
    {
        "updated",
        get_timestamp,
    },

    -- The version field determines which Norg version was used when
    -- the file was created.
    {
        "version",
        function()
            return config.norg_version
        end,
    },
}

-- For all of the currently configured template entries, fall back to default handling
-- if the configuration omits the handler function. This allows an end user to specify
-- they want an entry in the generated metadata but they do not want to override the
-- default value for that entry by adding a singleton (like { "description" }) to the
-- template.
local function fill_template_defaults()
    local function match_first(comparand)
        return function(_key, value) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
            if value[1] == comparand then
                return value
            else
                return nil
            end
        end
    end

    module.config.public.template = lib.map(
        module.config.public.template,
        function(_key, elem) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
            if not elem[2] then
                return lib.filter(default_template, match_first(elem[1]))
            end
        end
    )
end

module.setup = function()
    return { requires = { "core.autocommands", "core.integrations.treesitter" } }
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
    template = default_template,

    -- Custom author name that overrides default value if not nil or empty
    -- Default value is autopopulated by querying the current user's system username.
    author = "",

    -- Timezone information in the timestamps
    -- - "utc" the timestamp is in UTC+0
    -- - "local" the timestamp is in the local timezone
    -- - "implicit-local" like "local", but the timezone information is omitted from the timestamp
    timezone = "local",

    -- Whether or not to call `:h :undojoin` just before changing the timestamp in
    -- `update_metadata`. This will make your undo key undo the last change before writing the file
    -- in addition to the timestamp change. This will move your cursor to the top of the file. For
    -- users with an autosave plugin, this option must be paired with keybinds for undo/redo to
    -- avoid problems with undo tree branching:
    -- ```lua
    -- ["core.keybinds"] = {
    --   config = {
    --     hook = function(keybinds)
    --       keybinds.map("norg", "n", "u", function()
    --         require("neorg.modules.core.esupports.metagen.module").public.skip_next_update()
    --         local k = vim.api.nvim_replace_termcodes("u<c-o>", true, false, true)
    --         vim.api.nvim_feedkeys(k, 'n', false)
    --       end)
    --       keybinds.map("norg", "n", "<c-r>", function()
    --         require("neorg.modules.core.esupports.metagen.module").public.skip_next_update()
    --         local k = vim.api.nvim_replace_termcodes("<c-r><c-o>", true, false, true)
    --         vim.api.nvim_feedkeys(k, 'n', false)
    --       end)
    --     end,
    --   },
    -- },
    -- ```
    undojoin_updates = false,
}

module.private = {
    buffers = {},
    listen_event = "none",
    skip_next_update = false,
}

---@class core.esupports.metagen
module.public = {
    --- Returns true if there is a `@document.meta` tag in the current document
    ---@param buf number #The buffer to check in
    ---@return boolean,table #Whether the metadata was present, and the range of the metadata node
    is_metadata_present = function(buf)
        local query = utils.ts_parse_query(
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

    --- Skip the next call to update_metadata
    skip_next_update = function()
        module.private.skip_next_update = true
    end,

    ---@class core.esupports.metagen.metadata
    ---@field title? function|string the title of the note
    ---@field description? function|string the description of the note
    ---@field authors? function|string the authors of the note
    ---@field categories? function|string the categories of the note
    ---@field created? function|string a timestamp of creation time for the note
    ---@field updated? function|string a timestamp of last time the note was updated
    ---@field version? function|string the neorg version

    --- Creates the metadata contents from the provided metadata table (defaulting to the configuration's template).
    ---@param buf number #The buffer to query potential data from
    ---@param metadata? core.esupports.metagen.metadata #Table of metadata, overrides defaults if present
    ---@return table #A table of strings that can be directly piped to `nvim_buf_set_lines`
    construct_metadata = function(buf, metadata)
        local template = module.config.public.template
        local whitespace = type(module.config.public.tab) == "function" and module.config.public.tab()
            or module.config.public.tab
        local delimiter = type(module.config.public.delimiter) == "function" and module.config.public.delimiter()
            or module.config.public.delimiter

        local result = {
            "@document.meta",
        }

        for _, data in ipairs(template) do
            if metadata and metadata[data[1]] then
                -- override with data from metadata table
                data = { data[1], metadata[data[1]] }
            end
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
    ---@param metadata? core.esupports.metagen.metadata #Table of metadata data, overrides defaults if present
    inject_metadata = function(buf, force, metadata)
        local present, data = module.public.is_metadata_present(buf)

        if force or not present then
            local constructed_metadata = module.public.construct_metadata(buf, metadata)
            vim.api.nvim_buf_set_lines(buf, data.range[1], data.range[2], false, constructed_metadata)
        end
    end,

    update_metadata = function(buf)
        if module.private.skip_next_update then
            module.private.skip_next_update = false
            return
        end

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

        for _, tree in pairs(languagetree:children()) do
            if tree:lang() ~= "norg_meta" or meta_root then
                goto continue
            end

            local meta_tree = tree:parse()[1]

            if not meta_tree then
                goto continue
            end

            meta_root = meta_tree:root()
            ::continue::
        end

        if not meta_root then
            return
        end

        -- Capture current date from config
        local current_date = ""
        for _, val in ipairs(module.config.public.template) do
            if val[1] == "updated" then
                current_date = val[2]() ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
            end
        end

        local query = utils.ts_parse_query(
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

                    if module.config.public.undojoin_updates then
                        vim.cmd.undojoin()
                    end
                    vim.api.nvim_buf_set_text(
                        buf,
                        range.row_start,
                        range.column_start,
                        range.row_end,
                        range.column_end,
                        { current_date } ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
                    )
                end
            end
        end
    end,
}

module.load = function()
    -- combine user-defined template with defaults
    fill_template_defaults()

    modules.await("core.neorgcmd", function(neorgcmd)
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
    elseif event.type == "core.dirman.events.file_created" then
        if event.content.opts.metadata then
            module.public.inject_metadata(event.content.buffer, true, event.content.opts.metadata)
        end
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
    ["core.dirman"] = {
        ["file_created"] = true,
    },
}

return module
