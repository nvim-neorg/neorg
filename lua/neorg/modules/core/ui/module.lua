--[[
    File: Core-UI
    Title: Module for managing and displaying UIs to the user.
	Summary: A set of public functions to help developers create and manage UI (selection popups, prompts...) in their modules.
    Internal: true
    ---
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.ui")

module.private = {
    windows = {},
    namespace = vim.api.nvim_create_namespace("core.ui"),
}

module.setup = function()
    return {
        imports = {
            "selection_popup",
            "text_popup",
            "calendar",
        },
    }
end

---@class core.ui
module.public = {
    --- Returns a table in the form of { width, height } containing the width and height of the current window
    ---@param half boolean #If true returns a position that could be considered the center of the window
    get_window_size = function(half)
        return half
                and {
                    math.floor(vim.opt_local.columns:get() / 2),
                    math.floor(vim.opt_local.lines:get() / 2),
                }
            or { vim.opt_local.columns:get(), vim.opt_local.lines:get() }
    end,

    --- Returns a modified version of floating window options.
    ---@param modifiers table #This option set has two values - center_x and center_y.
    --                           If they either of them is set to true then the window gets centered on that axis.
    ---@param config table #A table containing regular Neovim options for a floating window
    apply_custom_options = function(modifiers, config)
        -- Default modifier options
        local user_options = {
            center_x = false,
            center_y = false,
        }

        -- Override the default options with the user provided options
        user_options = vim.tbl_extend("force", user_options, modifiers or {})

        -- Assign some default values to certain config options in case they're not specified
        config = vim.tbl_deep_extend("keep", config, {
            relative = "win",
            row = 0,
            col = 0,
            width = 100,
            height = 100,
        })

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

    --- Attempts to force close the window that holds the specified buffer
    ---@param buf number #The buffer ID whose parent window to close
    delete_window = function(buf)
        -- Get the name of the buffer with the specified ID
        local name = vim.api.nvim_buf_get_name(buf)

        if module.private.user_scrolloff then
            vim.o.scrolloff = module.private.user_scrolloff
        end

        if module.private.windows[name] ~= nil then
            -- Attempt to force close both the window and the buffer
            vim.api.nvim_win_close(module.private.windows[name], true)
        end

        vim.api.nvim_buf_delete(buf, { force = true })

        -- Reset the window ID to nil so it can be reused again
        module.private.windows[name] = nil
    end,

    --- Applies a set of options to a buffer
    ---@param buf number the buffer number to apply the options to
    ---@param option_list table a table of option = value pairs
    apply_buffer_options = function(buf, option_list)
        for option_name, value in pairs(option_list or {}) do
            vim.api.nvim_buf_set_option(buf, option_name, value)
        end
    end,

    ---Creates a new horizontal split at the bottom of the screen
    ---@param  name string the name of the buffer contained within the split (will have neorg:// prepended to it)
    ---@param  config table? a table of <option> = <value> keypairs signifying buffer-local options for the buffer contained within the split
    ---@param  height number? the height of the new split
    create_split = function(name, config, height)
        vim.validate({
            name = { name, "string" },
            config = { config, "table", true },
            height = { height, "number", true },
        })

        local bufname = "neorg://" .. name

        if vim.fn.bufexists(bufname) == 1 then
            log.error("Buffer '" .. name .. "' already exists")
            return
        end

        vim.cmd("below new")

        if height then
            vim.api.nvim_win_set_height(0, height)
        end

        local buf = vim.api.nvim_win_get_buf(0)

        local default_options = {
            swapfile = false,
            bufhidden = "hide",
            buftype = "nofile",
            buflisted = false,
            filetype = "neorg",
        }

        vim.api.nvim_buf_set_name(buf, bufname)
        vim.api.nvim_win_set_buf(0, buf)

        -- Keep user scrolloff for when the ui is closed
        -- We can't use vim.o.scrolloff here because it seems to get a weird value...
        module.private.user_scrolloff = vim.api.nvim_get_option("scrolloff")

        vim.api.nvim_buf_call(buf, function()
            vim.cmd("set scrolloff=999")
        end)

        vim.api.nvim_win_set_option(0, "number", false)
        vim.api.nvim_win_set_option(0, "relativenumber", false)

        -- Merge the user provided options with the default options and apply them to the new buffer
        module.public.apply_buffer_options(buf, vim.tbl_extend("keep", config or {}, default_options))

        -- Make sure to clean up the window if the user leaves the popup at any time
        vim.cmd(
            (
                "autocmd WinLeave,BufLeave,BufDelete <buffer=%s> ++once lua require('neorg.modules.core.ui.module').public.delete_window(%s)"
            ):format(buf, buf)
        )

        return buf, vim.api.nvim_get_current_win()
    end,

    --- Creates a new vertical split
    ---@param name string the name of the buffer
    ---@param config table a table of <option> = <value> keypairs signifying buffer-local options for the buffer contained within the split
    ---@param left boolean if true will spawn the vertical split on the left (default is right)
    ---@return buffer the buffer of the vertical split
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
            filetype = "neorg",
        }

        vim.api.nvim_buf_set_name(buf, "neorg://" .. name)
        vim.api.nvim_win_set_buf(0, buf)

        vim.api.nvim_win_set_option(0, "number", false)
        vim.api.nvim_win_set_option(0, "relativenumber", false)

        vim.api.nvim_win_set_buf(0, buf)

        -- Merge the user provided options with the default options and apply them to the new buffer
        module.public.apply_buffer_options(buf, vim.tbl_extend("keep", config or {}, default_options))

        return buf, vim.api.nvim_get_current_win()
    end,

    --- Creates a new display in which you can place organized data
    ---@param name string #The name of the display
    ---@param split_type string #"vsplitl"|"vsplitr"|"split"|"nosplit" - if suffixed with "l" vertical split will be spawned on the left, else on the right. "split" is a horizontal split.
    ---@param content table #A table of content for the display
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
    ---@param name string the name of the buffer *without* the .norg extension
    ---@param split_type string "vsplitl"|"vsplitr"|"split"|"nosplit" - if suffixed with "l" vertical split will be spawned on the left, else on the right. "split" is a horizontal split.
    ---@param config table|nil a table of { option = value } pairs that set buffer-local options for the created Neorg buffer
    ---@param opts table|nil
    ---   - opts.keybinds (boolean)             if false, will not use the default keybinds
    ---   - opts.del_on_autocommands (table)    delete buffer on specified autocommands
    create_norg_buffer = function(name, split_type, config, opts)
        vim.validate({
            name = { name, "string" },
            split_type = { split_type, "string" },
            config = { config, "table", true },
            opts = { opts, "table", true },
        })
        opts = vim.tbl_deep_extend(
            "force",
            { keybinds = true, del_on_autocommands = { "BufLeave", "BufDelete", "BufUnload" } },
            opts or {}
        )

        if not vim.tbl_contains({ "nosplit", "vsplitl", "vsplitr", "split" }, split_type) then
            log.error(
                "Unable to create display. Expected one of 'vsplitl', 'vsplitr', 'split' or 'nosplit', got",
                split_type,
                "instead."
            )
            return
        end

        local buf = (function()
            name = "norg/" .. name .. ".norg"

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

        if opts.keybinds == true then
            vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":bd<CR>", { noremap = true, silent = true })
            vim.api.nvim_buf_set_keymap(buf, "n", "q", ":bd<CR>", { noremap = true, silent = true })
        end

        module.public.apply_buffer_options(buf, config or {})

        -- Refresh the buffer forcefully and set up autocommands
        vim.cmd("edit")
        if opts.del_on_autocommands and #opts.del_on_autocommands ~= 0 then
            vim.cmd(
                "autocmd "
                    .. table.concat(opts.del_on_autocommands, ",")
                    .. (" <buffer=%s> silent! bd! %s"):format(buf, buf)
            )
        end

        return buf
    end,
}

module.private = {
    user_scrolloff = nil,
}

module.examples = {
    ["Create a selection popup"] = function()
        -- Creates the buffer
        local buffer = module.public.create_split("selection/Test selection")

        -- Binds a selection to that buffer
        local selection = module.public
            .begin_selection(buffer)
            :apply({
                -- A title will simply be text with a custom highlight
                title = function(self, text)
                    return self:text(text, "TSTitle")
                end,
            })
            :listener("destroy", { "<Esc>" }, function(self)
                self:destroy()
            end)
            :listener("go-back", { "<BS>" }, function(self)
                self:pop_page()
            end)

        selection
            :options({
                text = {
                    highlight = "TSUnderline",
                },
            })
            :title("Hello World!")
            :blank()
            :text("Flags:")
            :flag("<CR>", "finish")
            :flag("t", "test flag", function()
                log.warn("The test flag has been pressed!")
            end)
            :blank()
            :text("Other flags:")
            :rflag("a", "press me!", function()
                selection:setstate("test", "hello from the other side")

                -- Create more elements for the selection
                selection
                    :title("Another Title!")
                    :blank()
                    :text("Other Flags:")
                    :flag("a", "i do nothing :)")
                    :rflag("b", "yet another nested flag", function()
                        selection
                            :title("Final Title")
                            :blank()
                            :text("Btw, did you know that you can")
                            :text("Press <BS> to go back a page? Try it!")
                            :blank()
                            :text("Also, psst, pressing `g` will give you a small surprise")
                            :blank()
                            :flag("a", "does nothing too")
                            :listener("print-message", { "g" }, function()
                                log.warn("You are awesome :)")
                            end)
                    end)
            end)
            :stateof( -- To view this press `a` and then <BS> to go back
                "test",
                "This is a custom message: %s." --[[ you can supply a third argument which
                will forcefully render the message even if the state isn't present. The state will be replaced with a " " ]]
            )
    end,
}

return module
