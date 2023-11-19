-- TODO(vhyrro): separate the gtd.ui.capture module from the logic module (gtd.capture)

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
        }, { dir = "col" })
    )

    layout:mount()

    vim.api.nvim_win_call(main_capture_element.winid, function()
        vim.cmd.syntax([[match @neorg.gtd.context /#\S\+/]])
        vim.cmd.syntax([[match @neorg.gtd.association /@\S\+/]])
        vim.cmd.syntax([[match @neorg.gtd.urgency /\!\d\+/]])
        vim.cmd.syntax([[match @neorg.gtd.ontology /&\S\+/]])
        vim.cmd.syntax([[match @neorg.gtd.timeframe /\~\d\+\S\+/]])
    end)

    module.private.help_selection(main_capture_element, help_ui)

    do
        local help_enabled = false

        vim.keymap.set("n", "?", function()
            if not help_enabled then
                main_capture_element.border:set_text("bottom", nil, nil)

                layout:update(module.private.nui.layout.Box({
                    module.private.nui.layout.Box(main_capture_element, {
                        size = {
                            width = "100%",
                            height = 3,
                        },
                    }),
                    module.private.nui.layout.Box(help_ui, {
                        size = {
                            width = "100%",
                            height = "100%",
                        },
                    }),
                }, { dir = "col" }))
            else
                main_capture_element.border:set_text("bottom", " ? - help ", "center")

                layout:update(module.private.nui.layout.Box({
                    module.private.nui.layout.Box(main_capture_element, {
                        size = {
                            width = "100%",
                            height = 3,
                        },
                    }),
                }, { dir = "col" }))
            end

            help_enabled = not help_enabled
        end, { buffer = main_capture_element.bufnr })
    end

    vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
            layout:update()
        end,
    })
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
                bottom = "[1/2]",
                bottom_align = "center",
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

function module.private.help_selection(keybind_display, main_display)
    module.required["core.ui.selection_popup"]
        .begin_selection(main_display.bufnr, keybind_display.bufnr)
        :options({
            text = {
                highlight = "@text.reference",
            },
        })
        :title("Add Category To Note")
        :raw(
            { "tell jim to contact susan " },
            { "#work", "@neorg.gtd.context" },
            { " " },
            { "#meeting", "@neorg.gtd.context" }
        )
        :blank(2)
        :title("Associate a Task with an Entity")
        :raw({ "tell jim to contact susan " }, { "@jim", "@neorg.gtd.association" })
        :blank(2)
        :title("Attach an Urgency to the Task")
        :raw({ "notify jeremy of urgent task " }, { "!1", "@neorg.gtd.urgency" })
        :blank(2)
        :title("Declare an Estimated Timeframe for the Task")
        :raw({ "clean the room " }, { "~30min", "@neorg.gtd.timeframe" })
        :blank(2)
        :text("Press `>` for keybind help.")
        :locallistener({ ">" }, function(self)
            self:push_page()
            main_display.border:set_text("bottom", "[2/2]", "center")

            self:locallistener({ "<" }, function()
                main_display.border:set_text("bottom", "[1/2]", "center")
                self:pop_page()
            end)
        end)

    -- :flag("<LocalLeader>c", "Modify Contexts", function()
    --     vim.print("Contexts were modified.")
    -- end)
    -- :flag("<LocalLeader>c", "Modify Contexts", function()
    --     vim.print("Contexts were modified.")
    -- end)
end

return module
