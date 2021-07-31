--[[
	Module for supporting the user while editing. Esupports -> Editing Supports
	Currently provides custom and configurable indenting for Neorg files

USAGE:
	Esupports is part of the `core.defaults` metamodule, and hence should be available to most
	users right off the bat.
CONFIGURATION:
	<TODO>
REQUIRES:
	`core.autocommands` - for detecting whenever a new .norg file is entered
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.esupports")

function _neorg_indent_expr()
    local indent_amount, success

    -- First try and match all available current line checks
    if module.config.public.indent_config.current.enabled then
        for _, data in pairs(module.config.public.indent_config.current) do
            if type(data) == "table" and data.enabled then
                -- Check whether the line matches any of our criteria
                indent_amount, success = module.public.create_indent(data.regex, data.indent, true)
                -- If it does, then return that indent!
                if success then
                    return indent_amount
                end
            end
        end
    end

    -- Attempt to match the current indent level based on the previous nonblank line
    if module.config.public.indent_config.previous.enabled then
        for _, data in pairs(module.config.public.indent_config.previous) do
            if type(data) == "table" and data.enabled then
                -- Check whether the line matches any of our criteria
                indent_amount, success = module.public.create_indent(data.regex, data.indent, false)
                -- If it does, then return that indent!
                if success then
                    return indent_amount
                end
            end
        end
    end

    -- If no criteria were met, let neovim handle the rest
    return vim.fn.indent(vim.api.nvim_win_get_cursor(0)[1])
end

module.setup = function()
    return { success = true, requires = { "core.autocommands" } }
end

module.config.public = {
    indent = true,

    indent_config = {
        current = {
            enabled = true,

            heading1 = {
                enabled = true,
                regex = "(%s*%*%s+)(.*)",
                indent = function()
                    return 0
                end,
            },

            heading2 = {
                enabled = true,
                regex = "(%s*%*%*%s+)(.*)",
                indent = function()
                    return 1
                end,
            },

            heading3 = {
                enabled = true,
                regex = "(%s*%*%*%*%s+)(.*)",
                indent = function()
                    return 2
                end,
            },

            heading4 = {
                enabled = true,
                regex = "(%s*%*%*%*%*%s+)(.*)",
                indent = function()
                    return 3
                end,
            },

            tags = {
                enabled = true,
                regex = "%s*@[a-z0-9]+.*",
                indent = function()
                    return 0
                end,
            },
        },

        previous = {
            enabled = true,

            todo_items = {
                enabled = true,
                regex = "(%s*)%-%s+%[%s*[x*%s]%s*%]%s+.*",
                indent = function(matches)
                    return matches[1]:len()
                end,
            },

            headings = {
                enabled = true,
                regex = "(%s*%*+%s+)(.*)",
                indent = function(matches)
                    if matches[2]:len() > 0 then
                        return matches[1]:len()
                    else
                        return -1
                    end
                end,
            },

            unordered_lists = {
                enabled = true,
                regex = "(%s*)%-%s+.+",
                indent = function(matches)
                    return matches[1]:len()
                end,
            },
        },

        realtime = {
            enabled = true,

            heading1 = {
                enabled = true,
                regex = "%s*%*%s+(.*)",
                indent = function()
                    return 0
                end,
            },

            heading2 = {
                enabled = true,
                regex = "%s*%*%*%s+(.*)",
                indent = function()
                    return 1
                end,
            },

            heading3 = {
                enabled = true,
                regex = "%s*%*%*%*%s+(.*)",
                indent = function()
                    return 2
                end,
            },

            heading4 = {
                enabled = true,
                regex = "%s*%*%*%*%*%s+(.*)",
                indent = function()
                    return 3
                end,
            },

            tags = {
                enabled = true,
                regex = "%s*@[a-z0-9]+.*",
                indent = function()
                    return 0
                end,
            },
        },
    },

    folds = {
        enabled = true,
        foldlevel = 99,
    },
}

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("TextChangedI")
    module.required["core.autocommands"].enable_autocommand("BufWrite")
end

module.public = {

    -- @Summary Creates a new indent
    -- @Description Sets a new set of rules that when fulfilled will indent the text properly
    -- @Param  match (string) - a regex that should match the line above the newly placed line
    -- @Param  indent (function(matches) -> number) - a function that should return the level of indentation in spaces for that line
    -- @Param  current (boolean) - if true checks the current line rather than the previous non-blank line
    create_indent = function(match, indent, current)
        local line_number = current and vim.api.nvim_win_get_cursor(0)[1]
            or vim.fn.prevnonblank(vim.api.nvim_win_get_cursor(0)[1] - 1)

        -- If the line number above us is 0 then don't indent anything
        if line_number == 0 then
            return 0
        end

        -- nvim_buf_get_lines() doesn't work here for some reason :(
        local line = vim.fn.getline(line_number)

        -- Pack all the matches into this lua table
        local matches = { line:match("^(" .. match .. ")$") }

        -- If the match is successful
        if matches[1] and matches[1]:len() > 0 then
            -- Invoke the callback for indenting
            local indent_amount = indent(vim.list_slice(matches, 2))

            if indent_amount == -1 then
                indent_amount = vim.fn.indent(line)
            elseif not current then
                indent_amount = indent_amount + (vim.api.nvim_strwidth(line) - line:len())
            end

            -- Return success
            return indent_amount, true
        end

        -- If we haven't found a match, return nothing
        return nil, false
    end,

    -- @Summary Creates metadata for the current file
    -- @Description Pastes a @document.meta block at the top of the current document
    construct_metadata = function()
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        vim.api.nvim_put({
            "@document.meta",
            "\ttitle: " .. vim.fn.expand("%:t:r"),
            "\tdescription: ",
            "\tauthor: " .. require("neorg.external.helpers").get_username(),
            "\tcategories: ",
            "\tcreated: " .. os.date("%F"),
            "\tversion: " .. require("neorg.config").version,
            "@end",
            "",
        }, "l", false, true)

        vim.opt_local.modified = false
    end,

    -- @Summary Indents the current line
    -- @Description Performs real-time indentation of the current line
    indent_line = function()
        -- Loop through all the data present in the indent configuration
        for _, data in pairs(module.config.public.indent_config.realtime) do
            -- If the data we're dealing with is correct and it's enabled then
            if type(data) == "table" and data.enabled then
                -- Get the indent amount for the current line
                local indent_amount, success = module.public.create_indent(data.regex, data.indent, true)

                -- If we've managed to successfully indent the current line
                if success then
                    -- Cache the current line (before any changes)
                    local cursor_pos = vim.api.nvim_win_get_cursor(0)

                    -- Set the indentation level for the current line
                    local line = vim.api.nvim_get_current_line()
                    local sub = line:gsub("^%s*", (" "):rep(indent_amount))

                    -- If the line has undergone any changes
                    if sub ~= vim.api.nvim_get_current_line() then
                        -- Set the line to the newly indented line
                        vim.api.nvim_set_current_line(sub)

                        -- Calculate the difference in chars from before the indentation to set the cursor
                        -- accordingly (otherwise it would get offset in weird ways)
                        vim.api.nvim_win_set_cursor(
                            0,
                            {
                                cursor_pos[1],
                                cursor_pos[2]
                                    + (
                                        vim.api.nvim_strwidth(vim.api.nvim_get_current_line())
                                        - vim.api.nvim_strwidth(line)
                                    ),
                            }
                        )
                    end

                    break
                end
            end
        end
    end,
}

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" then
        if event.content.norg then
            if module.config.public.indent then
                vim.opt_local.indentexpr = "v:lua._neorg_indent_expr()"
            end

            -- If folds are enabled then handle them
            if module.config.public.folds.enabled then
                vim.opt_local.foldmethod = "expr"
                vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
                vim.opt_local.foldlevel = module.config.public.folds.foldlevel
            end

            -- If the first tag of the document isn't an existing document.meta tag then generate it
            local treesitter = neorg.modules.get_module("core.integrations.treesitter")

            if treesitter then
                local document_meta_tag = vim.tbl_filter(function(node)
                    return require("nvim-treesitter.ts_utils").get_node_text(node)[1] == "@document.meta"
                end, treesitter.get_all_nodes(
                    "tag"
                ))

                if vim.tbl_isempty(document_meta_tag) then
                    module.public.construct_metadata()
                end
            end
        end
    end

    -- If we have changed some text then attempt to auto-indent the current line
    if
        event.type == "core.autocommands.events.textchangedi" and module.config.public.indent_config.realtime.enabled
    then
        module.public.indent_line()
    end

    if event.type == "core.autocommands.events.bufwrite" then
        -- TODO
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
        textchangedi = true,
        bufwrite = false,
    },
}

return module
