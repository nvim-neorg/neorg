local module = neorg.modules.create("core.upgrade")

module.setup = function()
    return {
        requires = {
            "core.export",
            "core.neorgcmd",
            "core.integrations.treesitter",
        },
    }
end

module.config.public = {
    ask_for_backup = true,
}

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            upgrade = {
                ["current-file"] = {},
                -- ["current-directory"] = {},
                -- ["file"] = {},
                -- ["directory"] = {},
            },
        },
        data = {
            upgrade = {
                args = 1,
                subcommands = {
                    ["current-file"] = {
                        max_args = 1,
                        name = "core.upgrade.current-file",
                    },
                    -- ["current-directory"] = {
                    --     max_args = 1,
                    --     name = "core.upgrade.current-directory",
                    -- },
                },
            },
        },
    })
end

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.core.upgrade.current-file" then
        local buffer_name = vim.api.nvim_buf_get_name(event.buffer)

        if module.config.public.ask_for_backup then
            local halt = false

            vim.ui.select({ ("Create backup (%s.old)"):format(buffer_name), "Don't create backup" }, {
                prompt = "Upgraders tend to be rock solid, but it's always good to be safe.\nDo you want to back up this file?",
            }, function(_, idx)
                if idx == 1 then
                    local current_path = vim.fn.expand("%:p")
                    local ok, err = vim.loop.fs_copyfile(current_path, current_path .. ".old")

                    if not ok then
                        halt = true
                        log.error(("Failed to create backup (%s) - upgrading aborted."):format(err))
                        return
                    end
                else
                end
            end)

            if halt then
                return
            end
        end

        local function perform_upgrade(version)
            if not neorg.modules.is_module_loaded("core.export.norg_from_" .. version) then
                neorg.modules.load_module("core.export.norg_from_" .. version)
            end

            local exported = module.required["core.export"].export(event.buffer, "norg_from_" .. version)
            local filepath = vim.fn.fnamemodify(buffer_name, ":p")

            vim.loop.fs_open(filepath, "w", 438, function(err, fd)
                assert(
                    not err,
                    neorg.lib.lazy_string_concat("Failed to open file '", filepath, "' for export: ", err)
                )

                vim.loop.fs_write(fd, exported, 0, function(werr)
                    assert(
                        not werr,
                        neorg.lib.lazy_string_concat("Failed to write to file '", filepath, "' for export: ", werr)
                    )
                end)

                vim.schedule(neorg.lib.wrap(vim.notify, "Successfully upgraded 1 file!"))
            end)
        end

        if not event.content[1] then
            -- Grab from metadata
            local metadata = module.required["core.integrations.treesitter"].get_document_metadata(event.buffer)

            if not metadata or vim.tbl_isempty(metadata) then
                log.error("Unable to upgrade document - no metadata found!")
                return
            end

            if not metadata.version then
                log.error([[
Unable to upgrade document - metadata does not contain a `version` attribute!
In order to convert from an older version of the format properly, Neorg needs to know where it should start,
the version attribute is the only source of information on that!

Usually this attribute is auto-supplied when running `:Neorg inject-metadata`.

If you know the Neorg version that you made the document in, then you can supply it as an argument instead:
`:Neorg upgrade current-file <version>`

Make sure the version is supplied in the correct format!
                ]])
                return
            end

            if not perform_upgrade(metadata.version:gsub("%.", "_")) then
                return
            end
        else
            -- Use provided value instead
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.upgrade.current-file"] = true,
    },
}

return module
