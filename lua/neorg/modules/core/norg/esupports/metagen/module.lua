--[[
    File: Metagen
    Title: Generate Neorg metadata
    Summary: A Neorg module for generating document metadata automatically.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.esupports.metagen")

module.setup = function()
    return { requires = { "core.autocommands", "core.keybinds", "core.integrations.treesitter" } }
end

module.config.public = {
    -- One of "none"|"auto"|"<some-keybind>"
    type = "auto",

    -- How to generate a tabulation inside the `@document.meta` tag
    tab = function()
        if not vim.opt_local.expandtab then
            return "	"
        else
            return string.rep(" ", vim.opt_local.tabstop:get())
        end
    end,

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
        { "version", require("neorg.config").version },
    },
}

module.private = {
    buffers = {},
}

module.public = {
    neorg_commands = {
        definitions = {
            ["inject-metadata"] = {},
        },
        data = {
            ["inject-metadata"] = {
                args = 0,
                name = "inject-metadata",
            },
        },
    },

    is_metadata_present = function()
        local query = vim.treesitter.parse_query(
            "norg",
            [[
                 (ranged_tag
                     (tag_name) @name
                     (#eq? @name "document.meta")
                 )
            ]]
        )

        local root = module.required["core.integrations.treesitter"].get_document_root()

        local _, found = query:iter_matches(root, 0)()

        return found and found[1] and true
    end,

    construct_metadata = function()
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

        if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:len() > 0 then
            table.insert(result, "")
        end

        return result
    end,

    inject_metadata = function(force)
        if force or not module.public.is_metadata_present() then
            local constructed_metadata = module.public.construct_metadata()
            vim.api.nvim_buf_set_lines(0, 0, 0, false, constructed_metadata)
        end
    end,
}

module.load = function()
    if module.config.public.type == "auto" then
        module.required["core.autocommands"].enable_autocommand("BufEnter")
    elseif module.config.public.type ~= "none" then
        neorg.callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, key)
            key.map(
                "n",
                module.config.public.type,
                string.format(":lua neorg.modules.get_module('%s').inject_metadata()<CR>", module.name),
                { noremap = true, silent = true }
            )
        end)
    end
end

module.on_event = function(event)
    if
        event.type == "core.autocommands.events.bufenter"
        and event.content.norg
        and module.config.public.type == "auto"
        and vim.api.nvim_buf_get_option(0, "modifiable")
        and not module.private.buffers[vim.api.nvim_get_current_buf()]
    then
        module.public.inject_metadata()
        module.private.buffers[vim.api.nvim_get_current_buf()] = true
    elseif event.type == "core.neorgcmd.events.inject-metadata" then
        module.public.inject_metadata(true)
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
    },

    ["core.neorgcmd"] = {
        ["inject-metadata"] = true,
    },
}

return module
