--[[
    File: Qol-Toc
    Title: ToC Generation
    Summary: Generates a Table of Content from the Neorg file.
    ---
In order to use this feature, just add a `= TOC` at some place, and call:

- `:Neorg toc split` to generate a split in the side of your Toc (Table of Contents)
- `:Neorg toc inline` to generate a Toc right below the `= TOC` insertion
- `:Neorg toc toqflist` to send the table of contents to your quickfix list

--]]
require("neorg.modules.base")

local module = neorg.modules.create("core.norg.qol.toc")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.ui",
            "core.keybinds",
            "core.mode",
            "core.norg.esupports.hop",
            "core.autocommands",
            "core.neorgcmd",
        },
    }
end

module.load = function()
    -- Register keybinds for the toc buffer:
    --   - hop-toc-link: follow headings
    --   - close: close toc buffer
    module.required["core.keybinds"].register_keybinds(module.name, { "hop-toc-link", "close" })

    module.required["core.autocommands"].enable_autocommand("BufLeave")
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("BufDelete")
    module.required["core.autocommands"].enable_autocommand("QuitPre")

    -- Add neorgcmd capabilities
    -- All toc commands start with :Neorg toc ...
    module.required["core.neorgcmd"].add_commands_from_table({
        toc = {
            args = 1,
            condition = "norg",
            subcommands = {
                split = { args = 0, name = "toc.split" },
                inline = { args = 0, name = "toc.inline" },
                toqflist = { args = 0, name = "toc.toqflist" },
                close = { args = 0, name = "toc.close" },
            },
        },
    })
end

module.config.public = {
    -- If you use `default_toc_mode = "split"`, you can decide if you want the toc to persist until you close it.
    -- Else, it'll close automatically when following a link
    close_split_on_jump = false,
    -- Where to place the TOC (`"left"`/`"right"`)
    toc_split_placement = "left",
}

module.private = {
    toc_bufnr = nil,
    cur_bnr = nil,
    cur_win = nil,
    toc_namespace = nil,

    close_buffer = function(opts)
        opts = opts or {}

        if not opts.keep_buf then
            vim.api.nvim_buf_delete(module.private.toc_bufnr, { force = true })
            module.private.cur_bnr = nil
            module.private.toc_bufnr = nil
        end
    end,
}

module.public = {
    follow_link_toc = function()
        -- Get the link node from cursor
        local node = module.required["core.norg.esupports.hop"].lookahead_link_node()

        if not node then
            return
        end

        -- Parse the link before jumping
        local parsed_link = module.required["core.norg.esupports.hop"].parse_link(node, module.private.toc_bufnr)

        -- Follow the link on main norg file
        vim.api.nvim_set_current_win(module.private.cur_win)
        -- vim.api.nvim_win_set_buf(0, module.private.cur_bnr)
        module.required["core.norg.esupports.hop"].follow_link(node, nil, parsed_link)
    end,

    --- Find a Table of Contents insertions in the document and returns its data
    ---@return table A table that consist of two values: { item, parameters }.
    --- Parameters can be nil if no parameters to the insertion were given.
    find_toc = function()
        -- Extract any insertion that has a ToC value in it
        local query = vim.treesitter.parse_query(
            "norg",
            [[
            (insertion
            (insertion_prefix)
            item: (capitalized_word) @item
            parameters: (paragraph_segment)? @parameters
            (#match? @item "^T[oO][cC]$")
            )
            ]]
        )

        local exists = false
        local node_data = {
            item = nil,
            parameters = nil,
            line = nil,
        }

        -- The document root is required for iterating over query captures
        local root = module.required["core.integrations.treesitter"].get_document_root()

        if not root then
            return
        end

        -- All captures are looped over here
        for id, node in query:iter_captures(root, 0) do
            -- Extract the name of the capture from the captures table (this makes it easier to perform comparisons on)
            local capture = query.captures[id]

            -- If the capture name is "item" then we set the item variable inside of node_data
            -- It can also optionally be "parameters", in which case that variable will be set too
            node_data[capture] = node

            if node_data.line == nil then
                node_data.line = module.required["core.integrations.treesitter"].get_node_range(node).row_end
            end

            -- This is set to true to tell the program that we've encountered a node
            -- I don't think there's an easier way of doing this, as iter_captures returns a function,
            -- not a list of nodes. We can't simply check if that table of nodes is empty
            exists = true
        end

        if not exists then
            log.error(vim.trim([[
            Uh oh! We couldn't generate a Table of Contents because you didn't specify one in the document!
            You can do:
            = TOC <Optional custom name for the table of contents>
            Anywhere in your document. Doing so will cause the ToC to appear in that location during render.
            Type :messages to see full output
            ]]))
            return
        end

        return node_data
    end,

    --- Generates a Table Of Contents (doesn't display it)
    ---@param generator function the function to invoke for each node (used for building the toc)
    ---@param display_as_links boolean
    ---@return table a table of { text, highlight_group } pairs
    generate_toc = function(toc_data, generator, display_as_links)
        vim.validate({
            toc_data = { toc_data, "table" },
            generator = { generator, "function", true },
        })

        local ts = module.required["core.integrations.treesitter"]

        -- Initialize the default generator if it can't be found
        generator = generator
            or function(node, state)
                local node_type = node:type()

                if vim.startswith(node_type, "heading") and not vim.endswith(node_type, "prefix") then
                    local heading_level = tonumber(node_type:sub(8, 8))

                    local function join_text(text)
                        local out = {}
                        for k, v in ipairs(text) do
                            -- TODO: figure out how to do this in a single gsub
                            -- (it's not as trivial as it seems because we must
                            -- avoid that `(.+)` greedily includes the trailing
                            -- modifier...)
                            v = v:gsub("^(.+)%~$", "%1")
                            v = v:gsub("^%s*(.+)$", "%1")
                            out[k] = v
                        end
                        return table.concat(out, " ")
                    end

                    local line, _, _ = node:start()
                    local heading_text_node = ts.get_first_node("paragraph_segment", 0, node)
                    local heading_text = vim.split(vim.treesitter.query.get_node_text(heading_text_node, 0), "\n")

                    local prefix = string.rep(display_as_links and "-" or "*", heading_level)
                        .. (display_as_links and "> " or " ")
                    local text = prefix
                        .. (function()
                            if display_as_links then
                                return "{# " .. table.concat(heading_text, "") .. "}"
                            end
                            return join_text(heading_text)
                        end)()
                    return {
                        text = text,
                        highlight = "NeorgHeading" .. heading_level .. "Title",
                        level = heading_level,
                        state = state,
                        line = line + 1,
                    }
                end
            end

        local title = toc_data.parameters and ts.get_node_text(toc_data.parameters)
            or (display_as_links and "* " or "") .. "Table of Contents"
        local result = {
            {
                text = title,
                highlight = "@text.title",
                level = 1,
            },
            {
                text = "",
            },
        }

        local root = module.required["core.integrations.treesitter"].get_document_root()

        if not root then
            return
        end

        local state = {}

        -- Recursively go through all nodes and run the generator on each one
        -- If the generator returns a valid value then store it in the result
        ts.tree_map_rec(function(node)
            local output = generator(node, ts.get_node_text, state)

            if output then
                state = output.state
                table.insert(result, output)
            end
        end)

        return result
    end,

    --- Displays the table of contents to the user
    ---@param split boolean if true will spawn the vertical split on the right hand side
    display_toc = function(split)
        if
            module.private.toc_bufnr ~= nil
            or (module.private.toc_namespace ~= nil and vim.api.nvim_get_namespaces()["Neorg ToC"])
        then
            log.warn("Toc is already displayed.")
            return
        end
        local found_toc = module.public.find_toc()

        if not found_toc then
            return
        end

        local generated_toc = module.public.generate_toc(found_toc, nil, split)

        if not generated_toc then
            return
        end

        local virt_lines = {}
        for _, element in ipairs(generated_toc) do
            table.insert(virt_lines, { { element.text, element.highlight } })
        end

        if split then
            module.private.cur_bnr = vim.api.nvim_get_current_buf()
            module.private.cur_win = vim.api.nvim_get_current_win()

            local autocommands = neorg.lib.match(module.config.public.close_split_on_jump)({
                ["true"] = { "BufDelete", "BufUnload" },
                ["false"] = { "BufDelete", "BufUnload" },
            })

            local placement = neorg.lib.match(module.config.public.toc_split_placement)({
                right = "vsplitr",
                left = "vsplitl",
            })

            local buf = module.required["core.ui"].create_norg_buffer(
                "Neorg Toc",
                placement,
                nil,
                { keybinds = false, del_on_autocommands = autocommands }
            )
            module.private.toc_bufnr = buf

            local filter = function(a)
                return a.text
            end

            local size = math.floor(vim.api.nvim_win_get_width(0) / 3)
            vim.api.nvim_win_set_width(0, size)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.tbl_map(filter, generated_toc))
            vim.api.nvim_buf_set_option(buf, "modifiable", false)

            module.required["core.mode"].set_mode("toc-split")
            vim.cmd(string.format([[echom '%s']], "Press <ESC> or q to exit"))
            return
        end

        local namespace = vim.api.nvim_create_namespace("Neorg ToC")
        module.private.toc_namespace = namespace

        local extmarks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {})
        if #extmarks == 0 then
            vim.api.nvim_buf_set_extmark(0, namespace, found_toc.line, 0, { virt_lines = virt_lines })
        else
            vim.api.nvim_win_set_cursor(0, { found_toc.line + 1, 0 })
            return
        end
    end,

    --- Populates the quickfix list with the table of contents
    ---@param loclist boolean if true, uses the location list instead of the quickfix one
    toqflist = function(loclist)
        local found_toc = module.public.find_toc()

        if not found_toc then
            return
        end

        local generated_toc = module.public.generate_toc(found_toc)

        if not generated_toc then
            return
        end

        local bufnr = vim.api.nvim_win_get_buf(0)

        local qflist = {}
        for num, element in ipairs(generated_toc) do
            if num > 2 then
                table.insert(qflist, {
                    bufnr = bufnr,
                    lnum = element.line,
                    text = element.text,
                })
            end
        end

        if loclist == true then
            vim.fn.setloclist(0, qflist, "r")
        else
            vim.fn.setqflist(qflist, "r")
        end
    end,

    close = function()
        if module.private.toc_bufnr ~= nil then
            module.private.close_buffer()
        elseif module.private.toc_namespace ~= nil then
            local ns_id = vim.api.nvim_get_namespaces()["Neorg ToC"]
            vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
            module.private.toc_namespace = nil
        else
            log.warn("No Toc opened.")
        end
    end,
}

module.on_event = function(event)
    local module_name = event.split_type[1]
    local message = event.split_type[2]

    neorg.lib.match(module_name)({
        ["core.neorgcmd"] = function()
            neorg.lib.match(message)({
                ["toc.split"] = neorg.lib.wrap(module.public.display_toc, true),
                ["toc.inline"] = neorg.lib.wrap(module.public.display_toc),
                ["toc.toqflist"] = neorg.lib.wrap(module.public.toqflist),
                ["toc.close"] = neorg.lib.wrap(module.public.close),
            })
        end,
        ["core.keybinds"] = function()
            -- Do not process keybinds if user is not inside toc
            if module.private.toc_bufnr ~= vim.api.nvim_get_current_buf() then
                return
            end

            neorg.lib.match(message)({
                ["core.norg.qol.toc.hop-toc-link"] = neorg.lib.wrap(module.public.follow_link_toc),
                ["core.norg.qol.toc.close"] = neorg.lib.wrap(module.private.close_buffer),
            })
        end,
        ["core.autocommands"] = function()
            -- Do not process autocommands when toc is not active
            if module.private.toc_bufnr == nil then
                return
            end

            neorg.lib.match(message)({
                ["quitpre"] = function()
                    module.required["core.mode"].set_previous_mode()
                    module.private.close_buffer()
                end,
                ["bufleave"] = function()
                    module.required["core.mode"].set_previous_mode()
                end,
                ["bufenter"] = function()
                    -- Only set mode to toc when entering toc
                    if module.private.toc_bufnr ~= vim.api.nvim_get_current_buf() then
                        return
                    end
                    module.required["core.mode"].set_mode("toc-split")
                end,
            })
        end,
    })
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.qol.toc.hop-toc-link"] = true,
        ["core.norg.qol.toc.close"] = true,
    },
    ["core.autocommands"] = {
        bufleave = true,
        bufenter = true,
        bufdelete = true,
        quitpre = true,
    },
    ["core.neorgcmd"] = {
        ["toc.split"] = true,
        ["toc.inline"] = true,
        ["toc.toqflist"] = true,
        ["toc.close"] = true,
    },
}

return module
