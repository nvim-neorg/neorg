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
}

module = utils.require(module, "selection_popup")
module = utils.require(module, "text_popup")

return module
