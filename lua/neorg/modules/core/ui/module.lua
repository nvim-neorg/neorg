--[[
	Module for managing and displaying UIs to the user.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.ui")
local utils = require("neorg.external.helpers")

module.private = {
    windows = {},
    namespace = vim.api.nvim_create_namespace("core.ui"),
}

module.public = {
    -- TODO: Remove this. This is just a showcase
    test_display = function()
        -- Creates a buffer
        local buffer = module.public.create_split("selection/Test selection")

        -- Binds a selection to that buffer
        local selection = module.public.begin_selection(buffer):apply({
            -- A title will simply be text with a custom highlight
            title = function(self, text)
                return self:text(text, "TSTitle")
            end,
        })

        selection
            :options({
                text = {
                    highlight = "TSUnderline",
                },
            })
            :title("Hello World!")
            :blank()
            :text("Flags:")
            :flag("h", "World", function()
                log.warn("Pressed h")
            end)
            :blank()
            :text("Other flags:")
            :rflag("a", "press me plz", function()
                -- Create more elements for the selection
                selection
                    :title("Another title")
                    :blank()
                    :text("Other Flags:")
                    :flag("b", "go back", {
                        callback = function(data) -- TODO: Make the "data" variable useful
                            log.warn("Pressed n")

                            -- Move back to the previous page (yeah, we support that)
                            selection:pop_page()
                        end,
                        -- Don't destroy the selection popup when we press the flag
                        destroy = false,
                    })
                    :flag("a", "a value", function()
                        log.warn("Pressed a in the nested flag")
                    end)
            end)

        --[[ -- Applies some options beforehand
        selection:options({
            text = {
                highlight = "TSUnderline",
            }
        })

        -- Creates custom elements for use in the selection
        selection = selection:apply({
            -- A title will simply be text with a custom highlight
            title = function(self, text)
                return self:text(text, "TSTitle")
            end,
        })

        -- Render the newly created title element
        selection:title("This is a title!")

        -- Render a blank line
        selection:blank()

        -- Render some raw text with the TSUnderline highlight
        selection:text("Flags:", "TSUnderline")

        selection:detach()

        -- Create a flag "a" with the description "a description"
        selection:flag("a", "a description", function(data)
            -- Invoke this function when pressed!
            log.warn("Pressed!")

            -- Deletes the selection and the buffer
            selection:detach()
        end) ]]

        --[[ -- Creates a flag with subflags internally
        selection:nested_flag("b", "another flag", function(data)
            selection:text("Some text!")
            selection:flag("a", "another flag that does nothing")
        end) ]]
    end,

    -- @Summary Gets the current size of the window
    -- @Description Returns a table in the form of { width, height } containing the width and height of the current window
    -- @Param  half (boolean) - if true returns a position that could be considered the center of the window
    get_window_size = function(half)
        return half
                and {
                    math.floor(vim.api.nvim_win_get_width(0) / 2),
                    math.floor(vim.api.nvim_win_get_height(0) / 2),
                }
            or { vim.api.nvim_win_get_width(0), vim.api.nvim_win_get_height(0) }
    end,

    -- @Summary Applies a set of custom options to modify regular Neovim window opts
    -- @Description Returns a modified version of floating window options.
    -- @Param  modifiers (table) - this option set has two values - center_x and center_y.
    --                           If they either of them is set to true then the window gets centered on that axis.
    -- @Param  config (table) - a table containing regular Neovim options for a floating window
    apply_custom_options = function(modifiers, config)
        -- Default modifier options
        local user_options = {
            center_x = false,
            center_y = false,
        }

        -- Override the default options with the user provided options
        user_options = vim.tbl_extend("force", user_options, modifiers or {})

        -- Get the current window's dimensions except halved
        local halved_window_size = module.public.get_window_size(true)

        -- If we want to center along the x axis then return a configuration that does so
        if user_options.center_x then
            config.row = config.row + halved_window_size[2] - math.floor(config.height / 2)
        end

        -- If we want to center along the y axis then return a configuration that does so
        if user_options.center_y then
            config.col = config.col + halved_window_size[1] - math.floor(config.width / 2)
        end

        return config
    end,

    -- @Summary Deletes a window that holds a specific buffer
    -- @Description Attempts to force close the window that holds the specified buffer
    -- @Param  buf (number) - the buffer ID whose parent window to close
    delete_window = function(buf)
        -- Get the name of the buffer with the specified ID
        local name = vim.api.nvim_buf_get_name(buf)

        -- Attempt to force close both the window and the buffer
        vim.api.nvim_win_close(module.private.windows[name], true)
        vim.api.nvim_buf_delete(buf, { force = true })

        -- Reset the window ID to nil so it can be reused again
        module.private.windows[name] = nil
    end,

    --- Applies a set of options to a buffer
    --- @param buf number the buffer number to apply the options to
    --- @param option_list table a table of option = value pairs
    apply_buffer_options = function(buf, option_list)
        for option_name, value in pairs(option_list or {}) do
            vim.api.nvim_buf_set_option(buf, option_name, value)
        end
    end,

    ---Creates a new horizontal split at the bottom of the screen
    ---@param  name string the name of the buffer contained within the split (will have neorg:// prepended to it)
    ---@param  config table a table of <option> = <value> keypairs signifying buffer-local options for the buffer contained within the split
    create_split = function(name, config)
        vim.validate({
            name = { name, "string" },
            config = { config, "table", true },
        })

        vim.cmd("below new")

        local buf = vim.api.nvim_win_get_buf(0)

        local default_options = {
            swapfile = false,
            bufhidden = "hide",
            buftype = "nofile",
            buflisted = false,
        }

        vim.api.nvim_buf_set_name(buf, "neorg://" .. name)
        vim.api.nvim_win_set_buf(0, buf)

        vim.api.nvim_win_set_option(0, "number", false)
        vim.api.nvim_win_set_option(0, "relativenumber", false)

        -- Merge the user provided options with the default options and apply them to the new buffer
        module.public.apply_buffer_options(buf, vim.tbl_extend("keep", config or {}, default_options))

        return buf
    end,

    --- Creates a new vertical split
    --- @param name string the name of the buffer
    --- @param config table a table of <option> = <value> keypairs signifying buffer-local options for the buffer contained within the split
    --- @param left boolean if true will spawn the vertical split on the left (default is right)
    --- @return buffer the buffer of the vertical split
    create_vsplit = function(name, config, left)
        vim.validate({
            name = { name, "string" },
            config = { config, "table" },
            left = { left, "boolean", true },
        })

        left = left or false

        vim.cmd("vsplit")

        if left then
            vim.cmd("wincmd H")
        end

        local buf = vim.api.nvim_create_buf(false, true)

        local default_options = {
            swapfile = false,
            bufhidden = "hide",
            buftype = "nofile",
            buflisted = false,
        }

        vim.api.nvim_buf_set_name(buf, "neorg://" .. name)
        vim.api.nvim_win_set_buf(0, buf)

        vim.api.nvim_win_set_option(0, "number", false)
        vim.api.nvim_win_set_option(0, "relativenumber", false)

        vim.api.nvim_win_set_buf(0, buf)

        -- Merge the user provided options with the default options and apply them to the new buffer
        module.public.apply_buffer_options(buf, vim.tbl_extend("keep", config or {}, default_options))

        return buf
    end,

    --- Creates a new display in which you can place organized data
    --- @param split_type string "vsplitl"|"vsplitr"|"split"|"nosplit" - if suffixed with "l" vertical split will be spawned on the left, else on the right. "split" is a horizontal split.
    --- @param content table a table of content
    create_display = function(name, split_type, content)
        if not vim.tbl_contains({ "nosplit", "vsplitl", "vsplitr", "split" }, split_type) then
            log.error(
                "Unable to create display. Expected one of 'vsplitl', 'vsplitr', 'split' or 'nosplit', got",
                split_type,
                "instead."
            )
            return
        end

        local namespace = vim.api.nvim_create_namespace("neorg://display/" .. name)

        local buf = (function()
            name = "display/" .. name

            if split_type == "vsplitl" then
                return module.public.create_vsplit(name, {}, true)
            elseif split_type == "vsplitr" then
                return module.public.create_vsplit(name, {}, false)
            elseif split_type == "split" then
                return module.public.create_split(name, {})
            else
                local buf = vim.api.nvim_create_buf(true, true)
                vim.api.nvim_buf_set_name(buf, name)
                return buf
            end
        end)()

        vim.api.nvim_win_set_buf(0, buf)

        local length = vim.fn.len(vim.tbl_filter(function(elem)
            return vim.tbl_isempty(elem) or (elem[3] == nil and true or elem[3])
        end, content))

        vim.api.nvim_buf_set_lines(buf, 0, length, false, vim.split(("\n"):rep(length), "\n", true))

        local line_number = 1
        local buffer = {}

        for i, text_info in ipairs(content) do
            if not vim.tbl_isempty(text_info) then
                local newline = text_info[3] == nil and true or text_info[3]

                table.insert(buffer, { text_info[1], text_info[2] or "Normal" })

                if i == #content or newline then
                    vim.api.nvim_buf_set_extmark(0, namespace, line_number - 1, 0, {
                        virt_text_pos = "overlay",
                        virt_text = buffer,
                    })
                    buffer = {}
                    line_number = line_number + 1
                end
            else
                line_number = line_number + 1
            end
        end

        vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":bd<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(buf, "n", "q", ":bd<CR>", { noremap = true, silent = true })

        vim.api.nvim_buf_set_option(buf, "modifiable", false)

        local cached_virtualedit = vim.opt.virtualedit:get()
        vim.opt.virtualedit = "all"

        vim.cmd(([[
            autocmd BufLeave,BufDelete <buffer=%s> set virtualedit=%s | silent! bd! %s
        ]]):format(buf, cached_virtualedit[1] or "", buf))

        return { buffer = buf, namespace = namespace }
    end,

    --- Creates a new Neorg buffer in a split or in the main window
    --- @param name string the name of the buffer *without* the .norg extension
    --- @param split_type string "vsplitl"|"vsplitr"|"split"|"nosplit" - if suffixed with "l" vertical split will be spawned on the left, else on the right. "split" is a horizontal split.
    --- @param config table a table of { option = value } pairs that set buffer-local options for the created Neorg buffer
    create_norg_buffer = function(name, split_type, config)
        vim.validate({
            name = { name, "string" },
            split_type = { split_type, "string" },
            config = { config, "table", true },
        })

        if not vim.tbl_contains({ "nosplit", "vsplitl", "vsplitr", "split" }, split_type) then
            log.error(
                "Unable to create display. Expected one of 'vsplitl', 'vsplitr', 'split' or 'nosplit', got",
                split_type,
                "instead."
            )
            return
        end

        local buf = (function()
            name = "buffer/" .. name .. ".norg"

            if split_type == "vsplitl" then
                return module.public.create_vsplit(name, {}, true)
            elseif split_type == "vsplitr" then
                return module.public.create_vsplit(name, {}, false)
            elseif split_type == "split" then
                return module.public.create_split(name, {})
            else
                local buf = vim.api.nvim_create_buf(true, true)
                vim.api.nvim_buf_set_name(buf, name)
                return buf
            end
        end)()

        vim.api.nvim_win_set_buf(0, buf)
        vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":bd<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(buf, "n", "q", ":bd<CR>", { noremap = true, silent = true })

        module.public.apply_buffer_options(buf, config or {})

        -- Refresh the buffer forcefully and set up autocommands
        vim.cmd(([[
            edit
            autocmd BufDelete,BufLeave,BufUnload <buffer=%s> silent! bd! %s
        ]]):format(buf, buf))

        return buf
    end,
}

module = utils.require(module, "selection_popup")
module = utils.require(module, "text_popup")

return module
