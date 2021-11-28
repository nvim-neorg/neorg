--[[
File: zettelkasten_module
Title: Zettelkasten module for neorg
Summary: Easily work with for a zettelkasten
---

How to use this module:
This module creates a couple of commands.
- `Neorg zettel new` create a new zettel
- `Neorg zettel random` edit a random zettel
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.zettelkasten")
local log = require("neorg.external.log")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.keybinds",
            "core.ui",
            "core.neorgcmd",
        },
    }
end

module.private = {
    create_charset = function()
        local charset = {}
        do -- [0-9a-zA-Z]
            for c = 48, 57 do
                table.insert(charset, string.char(c))
            end
            for c = 65, 90 do
                table.insert(charset, string.char(c))
            end
            for c = 97, 122 do
                table.insert(charset, string.char(c))
            end
        end
        return charset
    end,

    random_prefix = function(length)
        math.randomseed(os.clock() ^ 5)
        local res = ""
        for _ = 1, length do
            res = res .. module.config.private.charset[math.random(1, #module.config.private.charset)]
        end
        return res
    end,

    timestamp = function()
        -- Format date as YYYYMMDDHHMM
        return os.date("%Y%m%d%H%M")
    end,

    unix_timestamp = function()
        return os.time(os.date("!*t"))
    end,

    -- Write a very basic template to the end of the file. This is only save, if the file is newly created.
    inject_template = function(opts)
        local template = module.config.public.template

        local result = {}
        for _, data in ipairs(template) do
            table.insert(result, data[1] .. tostring(type(data[2]) == "function" and data[2](opts) or data[2]))
        end

        vim.api.nvim_buf_set_lines(0, -1, -1, false, result)
    end,
}

module.config.public = {
    -- Workspace name to use for gtd related lists
    workspace = "default",

    -- Choose from "random", "unix", "timestamp"
    id_generator = "timestamp",

    template = {
        {
            "* ",
            function(opts)
                return opts.title
            end,
        },
        { "", "" },
        { "* Related", "" },
        { "", "" },
        { "* Further Reading", "" },
        { "", "" },
        { "* References", "" },
    },
}

module.config.private = {
    id_fn = nil,

    -- Used to generate random characters for prefixes
    charset = module.private.create_charset(),
}

module.load = function()
    -- Choose prefix functions
    if module.config.public.id_generator == "random" then
        module.config.private.id_fn = module.private.random_prefix
    elseif module.config.public.id_generator == "unix" then
        module.config.private.id_fn = module.private.unix_timestamp
    elseif module.config.public.id_generator == "timestamp" then
        module.config.private.id_fn = module.private.timestamp
    else
        error("Unknown prefix function")
    end

    module.required["core.keybinds"].register_keybinds(module.name, { "zettel.new", "edit.random", "edit.id" })

    -- Add neorgcmd capabilities
    -- All zettelkasten commands start with :Neorg zettel ...
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            zettel = {
                new = {},
                edit = {
                    random = {},
                    id = {},
                },
            },
        },
        data = {
            zettel = {
                args = 1,
                subcommands = {
                    new = { args = 0, name = "zettelkasten.zettel.new" },
                    edit = {
                        subcommands = {
                            random = { args = 0, name = "zettelkasten.edit.random" },
                            id = { args = 1, name = "zettelkasten.edit.id" },
                        },
                    },
                },
            },
        },
    })
end

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        if vim.tbl_contains({ "zettelkasten.zettel.new", "core.zettelkasten.zettel.new" }, event.split_type[2]) then
            module.required["core.ui"].create_prompt("NeorgNewZettel", "Zettel Title: ", function(title)
                module.public.create_zettel(title)
            end, {
                center_x = true,
                center_y = true,
            }, {
                width = 50,
                height = 1,
                row = 10,
                col = 0,
            })
        elseif
            vim.tbl_contains({ "zettelkasten.edit.random", "core.zettelkasten.edit.random" }, event.split_type[2])
        then
            module.public.open_random_zettel()
        elseif vim.tbl_contains({ "zettelkasten.edit.id" }, event.split_type[2]) then
            module.public.open_zettel_by_id(event.content[1])
        elseif vim.tbl_contains({ "core.zettelkasten.edit.id" }, event.split_type[2]) then
            -- TODO: Would be nice to use a (telescope) picker here instead
            module.required["core.ui"].create_prompt("NeorgEditId", "Zettel id: ", function(id)
                module.public.open_zettel_by_id(id)
            end, {
                center_x = true,
                center_y = true,
            }, {
                width = 50,
                height = 1,
                row = 10,
                col = 0,
            })
        end
    end
end

module.public = {
    version = "0.0.1",

    create_zettel = function(title)
        -- Generate id/prefix
        local prefix = module.config.private.id_fn()

        -- Remove leading and trailing whitespace
        local stripped_title = string.lower(string.gsub(title, "^%s*(.-)%s*$", "%1"))
        local filename = string.format("%s-%s", prefix, string.gsub(stripped_title, "%s+", "-"))

        -- Create file
        module.required["core.norg.dirman"].create_file(filename, module.config.public.workspace)

        module.private.inject_template({ title = title })
    end,

    open_zettel_by_id = function(id)
        local zettels = module.required["core.norg.dirman"].get_norg_files(module.config.public.workspace)

        for _, zettel in ipairs(zettels) do
            -- TODO: Can they have a path prefix, which I should remove?
            local zid, _ = string.match(zettel, "([^-]+)-(.*).norg")

            if zid == id then
                module.required["core.norg.dirman"].create_file(zettel, module.config.public.workspace)
                break
            end
        end
    end,

    open_random_zettel = function()
        local zettels = module.required["core.norg.dirman"].get_norg_files(module.config.public.workspace)
        local random_zettel = zettels[math.random(#zettels)]
        module.required["core.norg.dirman"].open_file(module.config.public.workspace, random_zettel)
    end,
}

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.zettelkasten.zettel.new"] = true,
        ["core.zettelkasten.edit.random"] = true,
        ["core.zettelkasten.edit.id"] = true,
    },
    ["core.neorgcmd"] = {
        ["zettelkasten.zettel.new"] = true,
        ["zettelkasten.edit.random"] = true,
        ["zettelkasten.edit.id"] = true,
    },
}

return module
