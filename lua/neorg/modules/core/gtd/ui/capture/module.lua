local modules = require("neorg").modules

local module = modules.create("core.gtd.ui.capture")

local log = require("neorg.core.log")

module.setup = function()
    local ok, nui_popup = pcall(require, "nui.popup")

    if not ok then
        log.error("Neorg GTD must have `nui.nvim` installed to run!")
        return {
            success = false,
        }
    end

    module.private.nui = {
        popup = nui_popup,
        layout = require("nui.layout"),
    }
end

module.private = {
    nui = {
        popup = nil,
        layout = nil,
    },
}

function module.public.capture()
    module.public.create_capture_ui()
end

function module.public.create_capture_ui()
    local popup = module.private.nui.popup({
        position = "50%",
        size = {
            width = "50%",
            height = 1,
        },
        enter = true,
        focusable = true,
        zindex = 50,
        relative = "editor",
        border = {
            padding = {
                top = 1,
                bottom = 1,
                left = 1,
                right = 1,
            },
            style = "rounded",
            text = {
                top = " Capture ",
                top_align = "center",
                bottom = " ? - help ",
                bottom_align = "center",
            },
        },
    })

    popup:mount()

    vim.cmd.startinsert()

    popup:on("VimResized", function()
        popup:update_layout()
    end)

    vim.keymap.set({ "n", "i", "v" }, "<CR>", function()
        vim.cmd.stopinsert()
        pcall(vim.api.nvim_buf_delete, popup.bufnr, { force = true })
        pcall(vim.api.nvim_win_close, popup.winid, true)
    end, { buffer = popup.bufnr })
end

return module
