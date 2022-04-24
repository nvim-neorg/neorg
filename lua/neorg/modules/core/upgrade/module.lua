local module = neorg.modules.create("core.upgrade")

module.setup = function()
    return {
        requires = {
            "core.export",
            "core.neorgcmd",
            "core.integrations.treesitter"
        }
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
                -- ["file"] = {},
                -- ["directory"] = {},
                -- ["current-directory"] = {},
            }
        },
        data = {
            upgrade = {
                args = 1,
                subcommands = {
                    ["current-file"] = {
                        max_args = 1,
                        name = "core.upgrade.current-file",
                    }
                }
            }
        }
    })
end

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.core.upgrade.current-file" then
        local buffer_name = vim.api.nvim_buf_get_name(event.buffer)

        if module.config.public.ask_for_backup then
            vim.ui.select({ ("Create backup (%s.old)"):format(buffer_name), "Don't create backup" }, {
                prompt = "Upgraders tend to be rock solid, but it's always good to be safe.\nDo you want to back up this file?"
            }, function(_, idx)
                if idx == 1 then
                    local current_path = vim.fn.expand("%:p")
                    local ok, err = vim.loop.fs_copyfile(current_path, current_path .. ".old")

                    if not ok then
                        log.error(("Failed to create backup (%s) - upgrading aborted."):format(err))
                        return
                    end
                else
                end
            end)
        end

        if not event.content[1] then
            -- Grab from metadata
        else
            -- Use provided value instead
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.upgrade.current-file"] = true,
    }
}

return module
