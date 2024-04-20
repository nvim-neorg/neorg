--[[
    file: Core-Latex-Renderer
    title: Rendering LaTeX with image.nvim
    summary: An experimental module for inline rendering latex images.
    ---

This is an experimental module that requires nvim 0.10+. It renders LaTeX snippets as images
making use of the image.nvim plugin. By default, images are only rendered after running the
command: `:Neorg render-latex`.

Requires:
- The [image.nvim](https://github.com/3rd/image.nvim) neovim plugin.
- `latex` executable in path
- `dvipng` executable in path (normally comes with LaTeX)

There's a highlight group that controls the foreground color of the rendered latex:
`@norg.rendered.latex`, configurable in `core.highlights`
--]]
local nio
local neorg = require("neorg.core")
local module = neorg.modules.create("core.latex.renderer")
local modules = neorg.modules

assert(vim.re ~= nil, "Neovim 0.10.0+ is required to run the `core.renderer.latex` module!")

module.setup = function()
    return {
        requires = {
            "core.integrations.image",
            "core.integrations.treesitter",
            "core.autocommands",
            "core.neorgcmd",
            "core.highlights",
        },
    }
end

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

    -- Don't re-render anything until 200ms after the buffer has stopped changing
    debounce_ms = 200,

    -- Make the images larger or smaller by adjusting the scale
    scale = 1,
}

---@class Image
---@field geometry table
---@field rendered_geometry table
---@field path string
---@field is_rendered boolean
---@field id string
-- and many other fields that I don't necessarily need

---@class MathRange
---@field image Image our limited representation of an image
---@field range Range4 last range of the math block. Updated based on the extmark
---@field snippet string

---Compute and set the foreground color string
local function compute_foreground()
    local neorg_hi = neorg.modules.get_module("core.highlights")
    assert(neorg_hi, "Failed to load core.highlights")
    local hi = vim.api.nvim_get_hl(0, { name = "@neorg.rendered.latex", link = false })
    if not vim.tbl_isempty(hi) then
        local r, g, b = neorg_hi.hex_to_rgb(("%06x"):format(hi.fg))
        module.private.foreground = ("rgb %s %s %s"):format(r / 255., g / 255., b / 255.)
    else
        -- grey
        module.private.foreground = "rgb 0.5 0.5 0.5"
    end
end

module.load = function()
    local success, image = pcall(neorg.modules.get_module, module.config.public.renderer)

    assert(success, "Unable to load image module")

    nio = require("nio")

    -- compute the foreground color in rgb
    compute_foreground()

    ---@type string[] ids
    module.private.cleared_at_cursor = {}

    ---Image cache, latex_snippet to file path
    ---@type table<string, string>
    module.private.image_paths = {}

    ---@type table<string, MathRange>
    module.private.latex_images = {}

    ---@type table<string, number>
    module.private.extmark_ids = {}

    module.private.image_api = image
    module.private.extmark_ns = vim.api.nvim_create_namespace("neorg-latex-concealer")

    module.private.do_render = module.config.public.render_on_enter

    module.required["core.autocommands"].enable_autocommand("BufWinEnter")
    module.required["core.autocommands"].enable_autocommand("CursorMoved")
    module.required["core.autocommands"].enable_autocommand("TextChanged")
    module.required["core.autocommands"].enable_autocommand("TextChangedI")

    modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            ["render-latex"] = {
                name = "latex.render.render",
                min_args = 0,
                max_args = 1,
                subcommands = {
                    enable = {
                        args = 0,
                        name = "latex.render.enable",
                    },
                    disable = {
                        args = 0,
                        name = "latex.render.disable",
                    },
                },
                condition = "norg",
            },
        })
    end)
end

---Get the key for a given range
---@param range Range4
module.private.get_key = function(range)
    return ("%d:%d"):format(range[1], range[2])
end

---Clear an extmark for the given key if it exists
---@param key string
module.private.clear_extmark = function(key)
    if module.private.extmark_ids[key] then
        nio.api.nvim_buf_del_extmark(0, module.private.extmark_ns, module.private.extmark_ids[key])
        module.private.extmark_ids[key] = nil
    end
end

module.public = {
    ---@async
    async_latex_renderer = function()
        ---node range to image handle
        -- module.private.ranges = {}
        ---@type table<string, MathRange>
        local next_images = {}
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
                    module.required["core.integrations.treesitter"].get_node_text(node, nio.api.nvim_get_current_buf())
                latex_snippet = string.gsub(latex_snippet, "^%$|", "$")
                latex_snippet = string.gsub(latex_snippet, "|%$$", "$")

                local png_location = module.private.image_paths[latex_snippet]
                    or module.public.async_generate_image(latex_snippet)
                if not png_location then
                    return
                end
                module.private.image_paths[latex_snippet] = png_location
                local range = { node:range() }
                local key = module.private.get_key(range)

                if module.private.latex_images[key] then
                    local img = module.private.latex_images[key].image
                    if img.path == png_location and img.geometry.y == range[1] then
                        -- This is the same image that's already there.
                        next_images[key] = module.private.latex_images[key]
                        -- The range might have changed though
                        next_images[key].range = range
                        return
                    end
                end

                local img = module.private.image_api.new_image(
                    nio.api.nvim_get_current_buf(),
                    png_location,
                    module.required["core.integrations.treesitter"].get_node_range(node),
                    nio.api.nvim_get_current_win(),
                    module.config.public.scale,
                    not module.config.public.conceal
                )
                next_images[key] = { image = img, range = range, snippet = latex_snippet }
            end
        )

        -- remove any 'orphaned' images. These are images attached to a range that isn't in this
        -- list, or images that are going to be replaced.
        for key, limage in pairs(module.private.latex_images) do
            if not next_images[key] or next_images[key].image.id ~= limage.image.id then
                -- This is an image that no longer exists...
                module.private.image_api.clear({ [key] = limage })
                module.private.clear_extmark(key)
            end
        end
        for key, limage in pairs(next_images) do
            -- existing images in the same position, if it's a different snippet, clear it, b/c it's
            -- no longer accurate
            local existing_img = module.private.latex_images[key]
            if existing_img and existing_img.snippet ~= limage.snippet then
                module.private.image_api.clear({ [key] = existing_img })
                module.private.clear_extmark(key)
            end
        end
        module.private.latex_images = next_images
    end,

    ---Writes a latex snippet to a file and wraps it with latex headers to it will render nicely
    ---@async
    ---@param snippet string latex snippet (if it's math it should include the surrounding $$)
    ---@return string temp file path
    async_create_latex_document = function(snippet)
        local tempname = nio.fn.tempname()
        local tempfile = nio.file.open(tempname, "w")

        local content = table.concat({
            "\\documentclass[6pt]{standalone}",
            "\\usepackage{amsmath}",
            "\\usepackage{amssymb}",
            "\\usepackage{graphicx}",
            "\\begin{document}",
            snippet,
            "\\end{document}",
        }, "\n")

        tempfile.write(content)
        tempfile.close()

        return tempname
    end,

    ---Returns a filepath where the rendered image sits
    ---@async
    ---@param snippet string the full latex snippet to convert to an image
    ---@return string | nil
    async_generate_image = function(snippet)
        local document_name = module.public.async_create_latex_document(snippet)

        if not document_name then
            return
        end

        local cwd = nio.fn.fnamemodify(document_name, ":h")
        local create_dvi = nio.process.run({
            cmd = "latex",
            args = {
                "--interaction=nonstopmode",
                "--output-format=dvi",
                document_name,
            },
            cwd = cwd,
        })
        if not create_dvi or type(create_dvi) == "string" then
            return
        end
        local res = create_dvi.result()
        if res ~= 0 then
            return
        end

        local png_result = nio.fn.tempname()
        png_result = ("%s.png"):format(png_result)

        local dvipng = nio.process.run({
            cmd = "dvipng",
            args = {
                "-D",
                module.config.public.dpi,
                "-T",
                "tight",
                "-bg",
                "Transparent",
                "-fg",
                module.private.foreground,
                "-o",
                png_result,
                document_name .. ".dvi",
            },
        })

        if not dvipng or type(dvipng) == "string" then
            return
        end
        res = dvipng.result()
        if res ~= 0 then
            return
        end

        return png_result
    end,

    ---Actually renders the images (along with any extmarks it needs)
    ---@param images table<string, MathRange>
    render_inline_math = function(images)
        local conceallevel = vim.api.nvim_get_option_value("conceallevel", { win = 0 })
        local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
        local conceal_on = conceallevel >= 2 and module.config.public.conceal
        for key, limage in pairs(images) do
            local range = limage.range
            local image = limage.image
            if range[1] == cursor_row - 1 then
                table.insert(module.private.cleared_at_cursor, key)
                goto continue
            end
            if not image.is_rendered then
                module.private.image_api.render({ limage })
            end

            if conceal_on then
                if not module.private.extmark_ids[key] then
                    module.private.clear_extmark(key)
                    local id = vim.api.nvim_buf_set_extmark(0, module.private.extmark_ns, range[1], range[2], {
                        end_col = range[4],
                        conceal = "",
                        virt_text = { { (" "):rep(image.rendered_geometry.width or image.geometry.width) } },
                        virt_text_pos = "inline",
                        strict = false, -- this might be a problem... I'm not sure, it could also be fine.
                        invalidate = true,
                        undo_restore = false,
                    })
                    module.private.extmark_ids[key] = id
                end
            end
            ::continue::
        end
    end,
}

local running_proc = nil
local render_timer = nil
local function render_latex()
    if not module.private.do_render then
        if render_timer then
            render_timer:stop()
            render_timer:close()
            render_timer = nil
        end
        return
    end

    if not render_timer then
        render_timer = vim.uv.new_timer()
    end

    render_timer:start(module.config.public.debounce_ms, 0, function()
        render_timer:stop()
        render_timer:close()
        render_timer = nil

        if not running_proc then
            vim.schedule(function()
                running_proc = nio.run(
                    function()
                        module.public.async_latex_renderer()
                    end,
                    vim.schedule_wrap(function()
                        module.public.render_inline_math(module.private.latex_images)
                        running_proc = nil
                    end)
                )
            end)
        end
    end)
end

local function clear_at_cursor()
    if not module.private.do_render then
        return
    end

    if module.config.public.conceal and module.private.latex_images ~= nil then
        local cleared =
            module.private.image_api.clear_at_cursor(module.private.latex_images, vim.api.nvim_win_get_cursor(0)[1] - 1)
        for _, id in ipairs(cleared) do
            if module.private.extmark_ids[id] then
                vim.api.nvim_buf_del_extmark(0, module.private.extmark_ns, module.private.extmark_ids[id])
                module.private.extmark_ids[id] = nil
            end
        end
        for _, key in ipairs(module.private.cleared_at_cursor) do
            if not vim.tbl_contains(cleared, key) then
                -- this image was cleared b/c it was at our cursor, and now it should be rendered
                -- again
                module.public.render_inline_math({ [key] = module.private.latex_images[key] })
            end
        end
        module.private.cleared_at_cursor = cleared
    end
end

local function enable_rendering()
    module.private.do_render = true
    render_latex()
end

local function disable_rendering()
    module.private.do_render = false
    module.private.image_api.clear(module.private.latex_images)
    module.private.extmark_ids = {}
    vim.api.nvim_buf_clear_namespace(0, module.private.extmark_ns, 0, -1)
end

local function show_hidden()
    if not module.private.do_render then
        return
    end

    module.private.image_api.render(module.private.latex_images)
end

local function colorscheme_change()
    module.private.image_paths = {}
    if module.private.do_render then
        disable_rendering()
        vim.schedule(function()
            compute_foreground()
            enable_rendering()
        end)
    else
        vim.schedule_wrap(compute_foreground)()
    end
end

local event_handlers = {
    ["core.neorgcmd.events.latex.render.render"] = enable_rendering,
    ["core.neorgcmd.events.latex.render.enable"] = enable_rendering,
    ["core.neorgcmd.events.latex.render.disable"] = disable_rendering,
    ["core.autocommands.events.bufreadpost"] = render_latex,
    ["core.autocommands.events.bufwinenter"] = show_hidden,
    ["core.autocommands.events.cursormoved"] = clear_at_cursor,
    ["core.autocommands.events.textchanged"] = render_latex,
    ["core.autocommands.events.textchangedi"] = render_latex,
    ["core.autocommands.events.insertleave"] = render_latex,
    ["core.autocommands.events.colorscheme"] = colorscheme_change,
}

module.on_event = function(event)
    if event.referrer == "core.autocommands" and vim.bo[event.buffer].ft ~= "norg" then
        return
    end

    return event_handlers[event.type]()
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufreadpost = module.config.public.render_on_enter,
        bufwinenter = true,
        cursormoved = true,
        textchanged = true,
        textchangedi = true,
        insertleave = true,
        colorscheme = true,
    },
    ["core.neorgcmd"] = {
        ["latex.render.render"] = true,
        ["latex.render.enable"] = true,
        ["latex.render.disable"] = true,
    },
}
return module
