-- rev: 5d9c76b5c9927955f7c5d5d946397584e307f69f

local module = neorg.modules.create("core.upgrade")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.config.public = {
    -- Whether to prompt the user to back up their file
    -- every time they want to upgrade a `.norg` document.
    ask_for_backup = true,
}

module.load = function()
    neorg.modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            upgrade = {
                subcommands = {
                    ["current-file"] = {
                        name = "core.upgrade.current-file",
                        args = 0,
                    },

                    ["current-directory"] = {
                        name = "core.upgrade.current-directory",
                        args = 0,
                    },
                },
            },
        })
    end)
end

module.public = {
    upgrade = function(buffer)
        local tree = vim.treesitter.get_parser(buffer, "norg"):parse()[1]
        local ts = module.required["core.integrations.treesitter"]

        local final_file = {}

        ts.tree_map_rec(function(node)
            local output = neorg.lib.match(node:type())({
                [{ "_open", "_close" }] = function()
                    if node:parent():type() == "spoiler" then
                        return { text = "!", stop = true }
                    elseif node:parent():type() == "variable" then
                        return { text = "&", stop = true }
                    end
                end,

                _ = function()
                    if node:child_count() == 0 then
                        return { text = ts.get_node_text(node), stop = true }
                    end
                end,
            })

            if output and output.text then
                table.insert(final_file, output.text)
                return output.stop
            end
        end, tree)

        log.warn(final_file)
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.upgrade.current-file" then
        if module.config.public.ask_for_backup then
            local halt = false

            local buffer_name = vim.api.nvim_buf_get_name(event.buffer)

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

                    vim.notify("Backup successfully created!")
                end
            end)

            if halt then
                return
            end
        end

        -- local output = module.public.upgrade(buffer)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.upgrade.current-file"] = true,
        ["core.upgrade.current-directory"] = true,
    },
}

return module
