-- rev: 5d9c76b5c9927955f7c5d5d946397584e307f69f

local module = neorg.modules.create("core.upgrade")

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

module.on_event = function(event)
    if event.split_type[2] == "core.upgrade.current-file" then

    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.upgrade.current-file"] = true,
        ["core.upgrade.current-directory"] = true,
    },
}

return module
