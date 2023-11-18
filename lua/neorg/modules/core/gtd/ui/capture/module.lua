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

    return {
        requires = {
            "core.ui.selection_popup",
        },
    }
end

module.private = {
    nui = {
        popup = nil,
        layout = nil,
    },
}

function module.public.capture()
    -- TODO: When the help is displayed remove the `? - help` at
    -- the bottom of the top window.
    -- TODO: Make the selection popup permit taking keys from a different
    -- window.

    local main_capture_element = module.public.create_capture_ui()
    local help_ui = module.public.create_help_ui()

    local layout = module.private.nui.layout(
        {
            position = "50%",
            size = {
                width = "50%",
                height = "50%",
            },
        },
        module.private.nui.layout.Box({
            module.private.nui.layout.Box(
                main_capture_element,
                { size = {
                    width = "100%",
                    height = 3,
                } }
            ),
            module.private.nui.layout.Box(
                help_ui,
                { size = {
                    width = "100%",
                    height = "100%",
                } }
            ),
        }, { dir = "col" })
    )

    module.private.help_selection(help_ui.bufnr)

    vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
            layout:update()
        end,
    })

    layout:mount()
end

function module.public.create_capture_ui()
    local popup = module.private.nui.popup({
        enter = true,
        focusable = true,
        zindex = 50,
        border = {
            style = "rounded",
            text = {
                top = " Capture ",
                top_align = "center",
                bottom = " ? - help ",
                bottom_align = "center",
            },
        },
    })

    vim.keymap.set({ "n", "i", "v" }, "<CR>", function()
        vim.cmd.stopinsert()
        pcall(vim.api.nvim_buf_delete, popup.bufnr, { force = true })
        pcall(vim.api.nvim_win_close, popup.winid, true)
    end, { buffer = popup.bufnr })

    return popup
end

function module.public.create_help_ui()
    local popup = module.private.nui.popup({
        enter = false,
        focusable = false,
        zindex = 50,
        border = {
            style = "single",
            text = {
                top = " Help ",
                top_align = "center",
            },
        },
    })

    popup:on("VimResized", function()
        popup:update_layout()
    end)

    vim.keymap.set({ "n", "i", "v" }, "<CR>", function()
        vim.cmd.stopinsert()
        pcall(vim.api.nvim_buf_delete, popup.bufnr, { force = true })
        pcall(vim.api.nvim_win_close, popup.winid, true)
    end, { buffer = popup.bufnr })

    return popup
end

function module.private.help_selection(bufnr)
    module.required["core.ui.selection_popup"].begin_selection(bufnr):flag("a", "A very cool flag", function()
        vim.print("A was pressed!")
    end)
end

return module
