--[[
    file: Core-Latex-Renderer
    title: Rendering LaTeX with image.nvim
    summary: An experimental module for inline rendering latex images
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
            "core.dirman",
        },
    }
end

module.load = function()
    local success, image = pcall(neorg.modules.get_module, module.config.public.renderer)

    assert(success, "Unable to load image module")

    module.private.image = image
    module.private.dirman = neorg.modules.get_module("core.dirman")

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

module.public = {
    latex_renderer = function()
        module.private.ranges = {}
        module.private.tmp_dir = vim.fn.fnamemodify(vim.fn.tempname(), ":h")
        local latex_snippets = {}
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

                table.insert(latex_snippets, { snippet = latex_snippet, node = node })
                table.insert(module.private.ranges, { node:range() })
            end
        )
        local latex_jobs = {}
        for _, latex_snippet in pairs(latex_snippets) do
            local document_name = module.public.get_snippet_filename(latex_snippet.snippet)
            local image_filename = document_name .. ".png"
            if module.private.dirman.file_exists(image_filename) then
                module.private.image.new_image(
                    vim.api.nvim_get_current_buf(),
                    image_filename,
                    module.required["core.integrations.treesitter"].get_node_range(latex_snippet.node),
                    vim.api.nvim_get_current_win(),
                    module.config.public.scale,
                    not module.config.public.conceal
                )
            else -- start rendering job
                local job_id = module.public.start_parse_latex_job(latex_snippet.snippet)
                table.insert(latex_jobs, {
                    job_id = job_id,
                    snippet = latex_snippet.snippet,
                    document_name = document_name,
                    node = latex_snippet.node,
                })
            end
        end
        local render_jobs = {}
        for _, job in pairs(latex_jobs) do
            vim.fn.jobwait({ job.job_id })
            local png_result = job.document_name .. ".png"
            local render_job = vim.fn.jobstart(
                "dvipng -D "
                    .. tostring(module.config.public.dpi)
                    .. " -T tight -bg Transparent -fg 'cmyk 0.00 0.04 0.21 0.02' -o "
                    .. png_result
                    .. " "
                    .. job.document_name
                    .. ".dvi",
                { cwd = vim.fn.fnamemodify(job.document_name, ":h") }
            )
            table.insert(render_jobs, { job_id = render_job, image = png_result, node = job.node })
        end
        for _, job in pairs(render_jobs) do
            vim.fn.jobwait({ job.job_id })
            module.private.image.new_image(
                vim.api.nvim_get_current_buf(),
                job.image,
                module.required["core.integrations.treesitter"].get_node_range(job.node),
                vim.api.nvim_get_current_win(),
                module.config.public.scale,
                not module.config.public.conceal
            )
        end
        module.private.images = module.private.image.get_images()
    end,

    get_snippet_filename = function(snippet)
        return module.private.tmp_dir .. "/" .. vim.base64.encode(snippet)
    end,

    create_latex_document = function(snippet)
        local snippet_filename = module.public.get_snippet_filename(snippet)

        local snippet_file = io.open(snippet_filename, "w")

        if not snippet_file then
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

        snippet_file:write(content)
        snippet_file:close()

        return snippet_filename
    end,

    -- Returns a handle to the latex rendering job
    -- This prevents blocking when there are many latex snippets.
    start_parse_latex_job = function(snippet)
        local document_name = module.public.create_latex_document(snippet)

        if not document_name then
            return
        end

        local cwd = vim.fn.fnamemodify(document_name, ":h")
        return vim.fn.jobstart(
            "latex  --interaction=nonstopmode --output-dir=" .. cwd .. " --output-format=dvi " .. document_name,
            { cwd = cwd }
        )
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

    -- make the images larger or smaller by adjusting the scale
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
