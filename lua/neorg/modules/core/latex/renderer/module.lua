--[[
    file: Core-Latex-Renderer
    title: Rendering LaTeX with image.nvim
    summary: An experimental module for inline rendering latex images.
    ---

This is an experimental module that requires nvim 0.10+. It renders LaTeX snippets as images
making use of the image.nvim plugin. By default, images are only rendered after running the
command: `:Neorg render-latex`.

Requires [image.nvim](https://github.com/3rd/image.nvim).
--]]
local neorg = require("neorg.core")
local module = neorg.modules.create("core.latex.renderer")
local modules = neorg.modules

assert(vim.re ~= nil, "Neovim 0.10.0+ is required to run the `core.renderer.latex` module!")

module.setup = function()
    return {
        wants = {
            "core.integrations.image",
        },
        requires = {
            "core.integrations.treesitter",
            "core.autocommands",
            "core.neorgcmd",
        },
    }
end

module.load = function()
    local success, image = pcall(neorg.modules.get_module, module.config.public.renderer)

    assert(success, "Unable to load image module")

    module.private.image = image

    module.required["core.autocommands"].enable_autocommand("BufWinEnter")
    module.required["core.autocommands"].enable_autocommand("CursorMoved")
    module.required["core.autocommands"].enable_autocommand("TextChanged")
    module.required["core.autocommands"].enable_autocommand("TextChangedI")
    module.required["core.autocommands"].enable_autocommand("TextChangedP")
    module.required["core.autocommands"].enable_autocommand("TextChangedT")

    modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            ["render-latex"] = {
                name = "core.latex.renderer.render",
                args = 0,
                condition = "norg",
            },
        })
    end)
end

---@class core.latex.renderer
module.public = {
    latex_renderer = function()
        module.private.ranges = {}
        module.required["core.integrations.treesitter"].execute_query(
            [[
                (
                    (inline_math) @latex
                    (#offset! @latex 0 1 0 -1)
                )
            ]],
            function(query, id, node)
                if query.captures[id] ~= "latex" then
                    return
                end

                local latex_snippet =
                    module.required["core.integrations.treesitter"].get_node_text(node, vim.api.nvim_get_current_buf())

                local png_location = module.public.parse_latex(latex_snippet)

                module.private.image.new_image(
                    vim.api.nvim_get_current_buf(),
                    png_location,
                    module.required["core.integrations.treesitter"].get_node_range(node),
                    vim.api.nvim_get_current_win(),
                    module.config.public.scale,
                    not module.config.public.conceal
                )

                table.insert(module.private.ranges, { node:range() })
            end
        )
        module.private.images = module.private.image.get_images()
    end,
    create_latex_document = function(snippet)
        local tempname = vim.fn.tempname()

        local tempfile = io.open(tempname, "w")

        if not tempfile then
            return
        end

        local content = table.concat({
            "\\documentclass[6pt]{standalone}",
            "\\usepackage{amsmath}",
            "\\usepackage{amssymb}",
            "\\usepackage{graphicx}",
            "\\begin{document}",
            snippet,
            "\\end{document}",
        }, "\n")

        tempfile:write(content)
        tempfile:close()

        return tempname
    end,

    -- Returns a handle to an image containing
    -- the rendered snippet.
    -- This handle can then be delegated to an external renderer.
    parse_latex = function(snippet)
        local document_name = module.public.create_latex_document(snippet)

        if not document_name then
            return
        end

        local cwd = vim.fn.fnamemodify(document_name, ":h")
        vim.fn.jobwait({
            vim.fn.jobstart(
                "latex  --interaction=nonstopmode --output-dir=" .. cwd .. " --output-format=dvi " .. document_name,
                { cwd = cwd }
            ),
        })

        local png_result = vim.fn.tempname()
        -- TODO: Make the conversions async via `on_exit`
        vim.fn.jobwait({
            vim.fn.jobstart(
                "dvipng -D "
                    .. tostring(module.config.public.dpi)
                    .. " -T tight -bg Transparent -fg 'cmyk 0.00 0.04 0.21 0.02' -o "
                    .. png_result
                    .. " "
                    .. document_name
                    .. ".dvi",
                { cwd = vim.fn.fnamemodify(document_name, ":h") }
            ),
        })

        return png_result
    end,
    render_inline_math = function(images)
        local conceal_on = (vim.wo.conceallevel >= 2) and module.config.public.conceal
        if conceal_on then
            table.sort(images, function(a, b)
                return a.internal_id < b.internal_id
            end)

            for i, range in ipairs(module.private.ranges) do
                vim.api.nvim_buf_set_extmark(
                    vim.api.nvim_get_current_buf(),
                    vim.api.nvim_create_namespace("concealer"),
                    range[1],
                    range[2],
                    {
                        id = i,
                        end_col = range[4],
                        conceal = "",
                        virt_text = { { (" "):rep(images[i].rendered_geometry.width) } },
                        virt_text_pos = "inline",
                    }
                )
            end
        end
    end,
}

module.config.public = {
    -- When true, images of rendered LaTeX will cover the source LaTeX they were produced from
    conceal = true,

    -- "Dots Per Inch" increasing this value will result in crisper images at the expense of
    -- performance
    dpi = 350,

    -- When true, images will render when a `.norg` buffer is entered
    render_on_enter = false,

    -- Module that renders the images. This is currently the only option
    renderer = "core.integrations.image",

    -- Make the images larger or smaller by adjusting the scale
    scale = 1,
}

local function render_latex()
    module.private.image.clear(module.private.images)
    neorg.modules.get_module("core.latex.renderer").latex_renderer()
    neorg.modules.get_module("core.latex.renderer").render_inline_math(module.private.images)
end

local function clear_latex()
    module.private.image.clear(module.private.images)
end

local function clear_at_cursor()
    if module.private.images ~= nil then
        module.private.image.render(module.private.images)
        module.private.image.clear_at_cursor(module.private.images, vim.api.nvim_win_get_cursor(0)[1] - 1)
    end
end

local event_handlers = {
    ["core.neorgcmd.events.core.latex.renderer.render"] = render_latex,
    ["core.autocommands.events.bufwinenter"] = render_latex,
    ["core.autocommands.events.cursormoved"] = clear_at_cursor,
    ["core.autocommands.events.textchanged"] = clear_latex,
    ["core.autocommands.events.textchangedi"] = clear_latex,
    ["core.autocommands.events.textchangedp"] = clear_latex,
    ["core.autocommands.events.textchangedt"] = clear_latex,
}

module.on_event = function(event)
    if event.referrer == "core.autocommands" and vim.bo[event.buffer].ft ~= "norg" then
        return
    end

    return event_handlers[event.type]()
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufwinenter = module.config.public.render_on_enter,
        cursormoved = true,
        textchanged = true,
        textchangedi = true,
        textchangedp = true,
        textchangedt = true,
    },
    ["core.neorgcmd"] = {
        ["core.latex.renderer.render"] = true,
    },
}
return module
