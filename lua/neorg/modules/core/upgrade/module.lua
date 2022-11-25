-- rev: 5d9c76b5c9927955f7c5d5d946397584e307f69f

-- TODO: Set old version of parser before reverting to "normal" one

local module = neorg.modules.create("core.upgrade")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
            "core.fs",
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

                    ["all-workspaces"] = {
                        name = "core.upgrade.all-workspaces",
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
        local line = 0

        ts.tree_map_rec(function(node)
            do
                local start_row, start_col = node:start()

                if line < start_row then
                    -- TODO(vhyrro): Maybe account for tabs as well?
                    table.insert(final_file, string.rep(" ", start_col))
                end

                line = start_row
            end

            local output = neorg.lib.match(node:type())({
                [{ "_open", "_close" }] = function()
                    if node:parent():type() == "spoiler" then
                        return { text = "!", stop = true }
                    elseif node:parent():type() == "variable" then
                        return { text = "&", stop = true }
                    elseif node:parent():type() == "inline_comment" then
                        return { text = "%", stop = true }
                    else
                        return { text = ts.get_node_text(node, buffer), stop = true }
                    end
                end,

                ["tag_name"] = function()
                    local next = node:next_named_sibling()
                    local text = ts.get_node_text(node, buffer)

                    if next and next:type() == "tag_parameters" then
                        return { text = table.concat({ text, " " }), stop = true }
                    end

                    -- HACK: This is a workaround for the TS parser
                    -- not having a _line_break node after the tag declaration
                    return { text = table.concat({ text, "\n" }), stop = true }
                end,

                ["tag_parameters"] = function()
                    return { text = ts.get_node_text(node, buffer), stop = true }
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
                            ts.get_node_text(name, buffer),
                            parameters and (" " .. ts.get_node_text(parameters, buffer)) or "",
                            parameters and "" or "\n",
                        }),
                        stop = true,
                    }
                end,

                _ = function()
                    if node:child_count() == 0 then
                        return { text = ts.get_node_text(node, buffer) or "", stop = true }
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

            vim.notify(
                "Upgraders tend to be rock solid, but it's always good to be safe.\nDo you want to back up this file?"
            )
            vim.ui.select({ ("Create backup (%s.old)"):format(path), "Don't create backup" }, {
                prompt = "Create backup?",
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
            assert(not err, neorg.lib.lazy_string_concat("Failed to open file '", path, "' for upgrade: ", err))

            vim.loop.fs_write(fd, output, 0, function(werr)
                assert(
                    not werr,
                    neorg.lib.lazy_string_concat("Failed to write to file '", path, "' for upgrade: ", werr)
                )
            end)

            vim.schedule(neorg.lib.wrap(vim.notify, "Successfully upgraded 1 file!"))
        end)
    elseif event.split_type[2] == "core.upgrade.current-directory" then
        local path = vim.fn.getcwd(event.window)

        do
            local halt = false

            vim.notify(
                ("Your current working directory is %s. This is the root that will be recursively searched for norg files.\nIs this the right directory?\nIf not, change the current working directory with `:cd` or `:lcd` and run this command again!"):format(
                    path
                )
            )
            vim.ui.select({ "This is the right directory", "I'd like to change it" }, {
                prompt = "Change directory?",
            }, function(_, idx)
                halt = (idx ~= 1)
            end)

            if halt then
                return
            end
        end

        if module.config.public.ask_for_backup then
            local halt = false

            vim.notify(
                "\nUpgraders tend to be rock solid, but it's always good to be safe.\nDo you want to back up this directory?"
            )
            vim.ui.select({ ("Create backup (%s.old)"):format(path), "Don't create backup" }, {
                prompt = "Create backup?",
            }, function(_, idx)
                if idx == 1 then
                    local ok, err = module.required["core.fs"].copy_directory(path, path .. ".old")

                    if not ok then
                        halt = true
                        log.error(
                            ("Unable to create backup directory '%s'! Perhaps the directory already exists and/or isn't empty? Formal error: %s"):format(
                                path .. ".old",
                                err
                            )
                        )
                        return
                    end
                end
            end)

            if halt then
                return
            end
        end

        -- The old value of `eventignore` is stored here. This is done because the eventignore
        -- value is set to ignore BufEnter events before loading all the Neorg buffers, as they can mistakenly
        -- activate the concealer, which not only slows down performance notably but also causes errors.
        local old_event_ignore = table.concat(vim.opt.eventignore:get(), ",")

        local file_counter, parsed_counter = 0, 0

        module.required["core.fs"].directory_map(path, function(name, _, nested_path)
            if not vim.endswith(name, ".norg") then
                return
            end

            file_counter = file_counter + 1

            local function check_counters()
                parsed_counter = parsed_counter + 1

                if parsed_counter >= file_counter then
                    vim.schedule(
                        neorg.lib.wrap(vim.notify, string.format("Successfully upgraded %d files!", file_counter))
                    )
                end
            end

            vim.schedule(function()
                local filepath = table.concat({ nested_path, "/", name })

                vim.opt.eventignore = "BufEnter"

                local output

                local buffer = vim.fn.bufadd(filepath)

                if not vim.api.nvim_buf_is_loaded(buffer) then
                    vim.fn.bufload(buffer)

                    vim.opt.eventignore = old_event_ignore

                    output = table.concat(module.public.upgrade(buffer))

                    vim.api.nvim_buf_delete(buffer, { force = true })
                else
                    output = table.concat(module.public.upgrade(buffer))
                end

                vim.loop.fs_open(filepath, "w+", 438, function(fs_err, fd)
                    assert(
                        not fs_err,
                        neorg.lib.lazy_string_concat("Failed to open file '", filepath, "' for upgrade: ", fs_err)
                    )

                    vim.loop.fs_write(fd, output, 0, function(werr)
                        assert(
                            not werr,
                            neorg.lib.lazy_string_concat("Failed to write to file '", filepath, "' for upgrade: ", werr)
                        )

                        check_counters()
                    end)
                end)
            end)
        end)
    elseif event.split_type[2] == "core.upgrade.all-workspaces" then
        local dirman = neorg.modules.get_module("core.norg.dirman")

        if not dirman then
            vim.notify("ERROR: `core.norg.dirman` is not loaded!")
            return
        end

        vim.notify("This behaviour isn't implemented yet!")
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.upgrade.current-file"] = true,
        ["core.upgrade.current-directory"] = true,
        ["core.upgrade.all-workspaces"] = true,
    },
}

return module
