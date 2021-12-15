require("neorg.modules.base")

local module = neorg.modules.create("core.norg.qol.toc")

module.setup = function()
    return { success = true, requires = { "core.integrations.treesitter", "core.ui", "core.keybinds","core.mode", "core.norg.esupports.hop"} }
end

module.load = function()
    module.required["core.keybinds"].register_keybind(module.name, "hop-toc-link")
end

module.public = {
    follow_link_toc = function(split,close_toc_split)
        local node = module.required["core.norg.esupports.hop"].lookahead_link_node()
        local previous_mode = module.required["core.mode"].get_previous_mode()
        module.required["core.mode"].set_mode(previous_mode)
        print("node:")
        print(vim.inspect(getmetatable(node)))

        vim.cmd("wincmd l")
        module.required["core.norg.esupports.hop"].follow_link(node)
    end,

    --- Find a Table of Contents insertions in the document and returns its data
    --- @return table A table that consist of two values: { item, parameters }.
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
            (#match? @item "^[tT][oO][cC]$")
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
    --- @param generator function the function to invoke for each node (used for building the toc)
    --- @param display_as_links boolean
    --- @return table a table of { text, highlight_group } pairs
    generate_toc = function(toc_data, generator, display_as_links)
        vim.validate({
            toc_data = { toc_data, "table" },
            generator = { generator, "function", true },
        })

        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
        local ts = module.required["core.integrations.treesitter"]

        -- Initialize the default generator if it can't be found
        generator = generator
            or function(node, get_text, state)
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
                    local heading_text = ts_utils.get_node_text(heading_text_node, 0)

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
                highlight = "TSAnnotation",
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
    --- @param split boolean if true will spawn the vertical split on the right hand side
    display_toc = function(split)
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
            local buf = module.required["core.ui"].create_norg_buffer("Neorg Toc", "vsplitl")
            module.required["core.mode"].set_mode("toc-split")

            local filter = function(a)
                return a.text
            end

            local size = math.floor(vim.api.nvim_win_get_width(0) / 3)
            vim.api.nvim_win_set_width(0, size)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.tbl_map(filter, generated_toc))
            -- vim.api.nvim_buf_set_option(buf, "modifiable", false)

            vim.cmd(string.format([[echom '%s']], "Press <ESC> or q to exit"))
            return
        end

        local namespace = vim.api.nvim_create_namespace("Neorg ToC")
        local extmarks = vim.api.nvim_buf_get_extmarks(0,namespace,0,-1,{})
        if #extmarks == 0 then
            vim.api.nvim_buf_set_extmark(0, namespace, found_toc.line, 0, { virt_lines = virt_lines })
        else
            vim.api.nvim_win_set_cursor(0, {found_toc.line+1,0})
            return
        end
    end,

    --- Populates the quickfix list with the table of contents
    --- @param loclist boolean if true, uses the location list instead of the quickfix one
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
}

module.on_event = function(event)
    if event.split_type[2] == "core.norg.qol.toc.hop-toc-link" then
        module.public.follow_link_toc(event.content[1])
        -- print("keybinding executed")
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.qol.toc.hop-toc-link"] = true,
    },
}

return module
