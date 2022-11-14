-- rev: 5d9c76b5c9927955f7c5d5d946397584e307f69f

-- TODO: Set old version of parser before reverting to "normal" one
-- TODO: Support directory export

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
                    elseif node:parent():type() == "inline_comment" then
                        return { text = "%", stop = true }
                    end
                end,

                ["tag_name"] = function()
                    local next = node:next_named_sibling()
                    local text = ts.get_node_text(node)

                    if next and next:type() == "tag_parameters" then
                        return { text = table.concat({ text, " " }), stop = true }
                    end

                    -- HACK: This is a workaround for the TS parser
                    -- not having a _line_break node after the tag declaration
                    return { text = table.concat({ text, "\n" }), stop = true }
                end,

                ["todo_item_undone"] = { text = "( ) ", stop = true },
                ["todo_item_pending"] = { text = "(-) ", stop = true },
                ["todo_item_done"] = { text = "(x) ", stop = true },
                ["todo_item_on_hold"] = { text = "(=) ", stop = true },
                ["todo_item_cancelled"] = { text = "(_) ", stop = true },
                ["todo_item_urgent"] = { text = "(!) ", stop = true },
                ["todo_item_uncertain"] = { text = "(?) ", stop = true },
                ["todo_item_recurring"] = { text = "(+) ", stop = true },

                ["unordered_link1_prefix"] = { text = "- ", stop = true },
                ["unordered_link2_prefix"] = { text = "- ", stop = true },
                ["unordered_link3_prefix"] = { text = "- ", stop = true },
                ["unordered_link4_prefix"] = { text = "- ", stop = true },
                ["unordered_link5_prefix"] = { text = "- ", stop = true },
                ["unordered_link6_prefix"] = { text = "- ", stop = true },

                ["ordered_link1_prefix"] = { text = "~ ", stop = true },
                ["ordered_link2_prefix"] = { text = "~ ", stop = true },
                ["ordered_link3_prefix"] = { text = "~ ", stop = true },
                ["ordered_link4_prefix"] = { text = "~ ", stop = true },
                ["ordered_link5_prefix"] = { text = "~ ", stop = true },
                ["ordered_link6_prefix"] = { text = "~ ", stop = true },

                ["marker_prefix"] = { text = "* ", stop = true },
                ["link_target_marker"] = { text = "* ", stop = true },

                ["insertion"] = function()
                    local name = node:named_child(1)
                    local parameters = node:named_child(2)

                    return {
                        text = table.concat({
                            ".",
                            ts.get_node_text(name),
                            parameters and (" " .. ts.get_node_text(parameters)) or "",
                            "\n",
                        }),
                        stop = true,
                    }
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

        return final_file
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.upgrade.current-file" then
        local path = vim.api.nvim_buf_call(event.buffer, function()
            return vim.fn.expand("%")
        end)

        if module.config.public.ask_for_backup then
            local halt = false

            vim.ui.select({ ("Create backup (%s.old)"):format(path), "Don't create backup" }, {
                prompt = "Upgraders tend to be rock solid, but it's always good to be safe.\nDo you want to back up this file?",
            }, function(_, idx)
                if idx == 1 then
                    local ok, err = vim.loop.fs_copyfile(path, path .. ".old")

                    if not ok then
                        halt = true
                        log.error(("Failed to create backup (%s) - upgrading aborted."):format(err))
                        return
                    end
                end
            end)

            if halt then
                return
            end
        end

        vim.notify("Begin upgrade...")

        local output = table.concat(module.public.upgrade(event.buffer))

        vim.loop.fs_open(path, "w", 438, function(err, fd)
            assert(not err, neorg.lib.lazy_string_concat("Failed to open file '", path, "' for export: ", err))

            vim.loop.fs_write(fd, output, 0, function(werr)
                assert(
                    not werr,
                    neorg.lib.lazy_string_concat("Failed to write to file '", path, "' for export: ", werr)
                )
            end)

            vim.schedule(neorg.lib.wrap(vim.notify, "Successfully upgraded 1 file!"))
        end)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.upgrade.current-file"] = true,
        ["core.upgrade.current-directory"] = true,
    },
}

return module
