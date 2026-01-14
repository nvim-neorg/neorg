-- lua/neorg/modules/core/latex/renderer/module.lua
local nio
local neorg = require("neorg.core")
local module = neorg.modules.create("core.latex.renderer")
local modules = neorg.modules

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
            "core.autocommands",
            "core.neorgcmd",
            "core.highlights",
        },
    }
end

module.config.public = {
    conceal = true,
    dpi = 350,
    render_on_enter = false,
    renderer = "core.integrations.snacks",
    debounce_ms = 200,
    min_length = 3,
    scale = 1,
}

---@class MathRange
---@field image any
---@field range table
---@field snippet string
---@field extmark_id number?
---@field real boolean

local function compute_foreground()
    local neorg_hi = neorg.modules.get_module("core.highlights")
    local color_hex = nil

    -- 1. Try specific Neorg latex highlight
    local hi = vim.api.nvim_get_hl(0, { name = "@norg.rendered.latex", link = false })
    if hi.fg then color_hex = hi.fg end

    -- 2. Fallback to Normal text color
    if not color_hex then
        local norm = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
        if norm.fg then color_hex = norm.fg end
    end

    -- 3. Convert to RGB string for dvipng
    if color_hex and neorg_hi then
        local r, g, b = neorg_hi.hex_to_rgb(("%06x"):format(color_hex))
        module.private.foreground = ("rgb %s %s %s"):format(r / 255., g / 255., b / 255.)
    else
        -- 4. Last Resort: Check background brightness
        if vim.o.background == "light" then
            module.private.foreground = "rgb 0.0 0.0 0.0" -- Black
        else
            module.private.foreground = "rgb 1.0 1.0 1.0" -- White
        end
    end
end

module.load = function()
    nio = require("nio")
    compute_foreground()

    module.private.cleared_at_cursor = {}
    module.private.image_paths = {}
    module.private.latex_images = {}
    module.private.extmark_ns = vim.api.nvim_create_namespace("neorg-latex-concealer")
    module.private.do_render = module.config.public.render_on_enter

    module.required["core.autocommands"].enable_autocommand("BufWinEnter")
    module.required["core.autocommands"].enable_autocommand("CursorMoved")
    module.required["core.autocommands"].enable_autocommand("TextChanged")
    module.required["core.autocommands"].enable_autocommand("TextChangedI")
    module.required["core.autocommands"].enable_autocommand("InsertLeave")

    modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            ["render-latex"] = {
                name = "latex.render.render",
                min_args = 0, max_args = 1,
                subcommands = {
                    enable = { args = 0, name = "latex.render.enable" },
                    disable = { args = 0, name = "latex.render.disable" },
                    toggle = { args = 0, name = "latex.render.toggle" },
                },
                condition = "norg",
            },
        })
    end)
end

module.private.get_renderer = function()
    if module.private._renderer_api then return module.private._renderer_api end
    local name = module.config.public.renderer
    local api = require("neorg").modules.get_module(name)
    
    if not api then
        local ok, mod = pcall(require, "neorg.modules." .. name .. ".module")
        if ok and mod then
            if mod.setup then mod.setup() end
            if mod.load then mod.load() end
            api = mod.public
        end
    end

    if not api then
         error(string.format("Latex Renderer: Could not load '%s'. Check your neorg.setup.", name))
    end

    module.private._renderer_api = api
    return api
end

module.private.get_key = function(range)
    return ("%d:%d"):format(range[1], range[2])
end

module.public = {
    async_latex_renderer = function(buf)
        local renderer = module.private.get_renderer()
        local new_limages = {}
        
        for _, limage in pairs(module.private.latex_images[buf] or {}) do
            if limage.extmark_id then
                local extmark = nio.api.nvim_buf_get_extmark_by_id(buf, module.private.extmark_ns, limage.extmark_id, {})
                if #extmark > 0 then
                    local new_key = module.private.get_key({ extmark[1], extmark[2] })
                    limage.real = false
                    new_limages[new_key] = limage
                end
            end
        end
        
        module.private.cleared_at_cursor = {}

        module.required["core.integrations.treesitter"].execute_query(
            [[ ((inline_math) @latex (#offset! @latex 0 1 0 -1)) ]],
            function(query, id, node)
                if query.captures[id] ~= "latex" then return end
                
                local original_snippet = module.required["core.integrations.treesitter"].get_node_text(node, buf)
                
                -- FIX: Only clean the surrounding pipe delimeters ($|...|$).
                local clean_snippet = original_snippet:gsub("^%$|", "$"):gsub("|%$$", "$")
                
                if #clean_snippet - 2 < module.config.public.min_length then return end

                local png_path = module.private.image_paths[clean_snippet] or module.public.async_generate_image(clean_snippet)
                if not png_path then return end
                
                module.private.image_paths[clean_snippet] = png_path
                local range = { node:range() }
                local key = module.private.get_key(range)

                if new_limages[key] and new_limages[key].snippet == clean_snippet then
                    new_limages[key].range = range
                    new_limages[key].real = true
                    return
                end

                local range_obj = module.required["core.integrations.treesitter"].get_node_range(node)

                local img = renderer.new_image(
                    buf, png_path, range_obj, nio.api.nvim_get_current_win(),
                    module.config.public.scale, not module.config.public.conceal
                )
                
                if img then
                    local existing_id = new_limages[key] and new_limages[key].extmark_id
                    new_limages[key] = {
                        image = img, range = range, snippet = clean_snippet,
                        real = true, extmark_id = existing_id
                    }
                end
            end, buf
        )
        
        nio.scheduler()
        
        for key, limage in pairs(new_limages) do
            if not limage.real then
                renderer.clear({ [key] = limage })
                if limage.extmark_id then
                    nio.api.nvim_buf_del_extmark(0, module.private.extmark_ns, limage.extmark_id)
                end
                new_limages[key] = nil
            end
        end
        module.private.latex_images[buf] = new_limages
    end,

    async_create_latex_document = function(snippet)
        local tempname = nio.fn.tempname()
        local f = nio.file.open(tempname, "w")
        if not f then return nil end
        f.write(table.concat({
            "\\documentclass[6pt]{standalone}",
            "\\usepackage{amsmath}", "\\usepackage{amssymb}", "\\usepackage{graphicx}",
            "\\begin{document}", snippet, "\\end{document}"
        }, "\n"))
        f.close()
        return tempname
    end,

    async_generate_image = function(snippet)
        local doc_name = module.public.async_create_latex_document(snippet)
        if not doc_name then return nil end
        
        local cwd = nio.fn.fnamemodify(doc_name, ":h")
        local p1 = nio.process.run({ cmd = "latex", args = { "--interaction=nonstopmode", "--output-format=dvi", doc_name }, cwd = cwd })
        if not p1 or p1.result() ~= 0 then return nil end

        local png_out = nio.fn.tempname() .. ".png"
        local p2 = nio.process.run({
            cmd = "dvipng",
            args = { "-D", tostring(module.config.public.dpi), "-T", "tight", "-bg", "Transparent", "-fg", module.private.foreground, "-o", png_out, doc_name .. ".dvi" }
        })
        if not p2 or p2.result() ~= 0 then return nil end
        
        return png_out
    end,

    render_inline_math = function(images, buffer)
        local renderer = module.private.get_renderer()
        local conceallevel = vim.api.nvim_get_option_value("conceallevel", { win = 0 })
        local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
        local conceal_on = conceallevel >= 2 and module.config.public.conceal

        for _, limage in pairs(images) do
            local range = limage.range
            local ext_opts = { end_col = range[4], strict = false, invalidate = true, undo_restore = false, id = limage.extmark_id }
            
            if module.config.public.conceal then
                if range[1] ~= cursor_row - 1 then
                    local size = renderer.image_size(limage.image, { height = module.config.public.scale })
                    ext_opts.virt_text = { { (" "):rep(size.width) } }
                    ext_opts.virt_text_pos = "inline"
                end
            end
            
            if conceal_on and range[1] ~= cursor_row - 1 then ext_opts.conceal = "" end
            limage.extmark_id = vim.api.nvim_buf_set_extmark(buffer, module.private.extmark_ns, range[1], range[2], ext_opts)
        end

        for key, limage in pairs(images) do
            if conceal_on and limage.range[1] == cursor_row - 1 then
                table.insert(module.private.cleared_at_cursor, key)
                renderer.clear({ limage })
                if limage.extmark_id then
                    vim.api.nvim_buf_set_extmark(buffer, module.private.extmark_ns, limage.range[1], limage.range[2], { virt_text = { { "" } } })
                end
            else
                renderer.render({ limage })
            end
        end
    end,
}

local running_proc, render_timer
local function render_latex()
    local buf = vim.api.nvim_get_current_buf()
    if not module.private.do_render then return end
    if render_timer then render_timer:close() end
    
    render_timer = vim.uv.new_timer()
    render_timer:start(module.config.public.debounce_ms, 0, function()
        render_timer:close(); render_timer = nil
        if not running_proc then
            running_proc = nio.run(function()
                nio.scheduler()
                module.public.async_latex_renderer(buf)
            end, vim.schedule_wrap(function()
                module.public.render_inline_math(module.private.latex_images[buf] or {}, buf)
                running_proc = nil
            end))
        end
    end)
end

local function clear_at_cursor()
    local buf = vim.api.nvim_get_current_buf()
    if not module.private.do_render or render_timer then return end
    if not module.config.public.conceal or not module.private.latex_images[buf] then return end

    local renderer = module.private.get_renderer()
    local cleared = renderer.clear_at_cursor(module.private.latex_images[buf], vim.api.nvim_win_get_cursor(0)[1] - 1)
    
    local to_render = {}
    for _, key in ipairs(module.private.cleared_at_cursor) do
        if not vim.tbl_contains(cleared, key) then
            to_render[key] = module.private.latex_images[buf][key]
        end
    end
    
    if next(to_render) then
        module.public.render_inline_math(to_render, buf)
    end
    module.private.cleared_at_cursor = cleared
end

local function enable_rendering() module.private.do_render = true; render_latex() end
local function disable_rendering()
    module.private.do_render = false
    local renderer = pcall(module.private.get_renderer) and module.private.get_renderer()
    for buf, images in pairs(module.private.latex_images) do
        if renderer then renderer.clear(images) end
        vim.api.nvim_buf_clear_namespace(buf, module.private.extmark_ns, 0, -1)
    end
    module.private.latex_images = {}
end
local function toggle_rendering() if module.private.do_render then disable_rendering() else enable_rendering() end end
local function show_hidden()
    local buf = vim.api.nvim_get_current_buf()
    if module.private.do_render then module.private.get_renderer().render(module.private.latex_images[buf] or {}) end
end

local event_handlers = {
    ["core.neorgcmd.events.latex.render.render"] = enable_rendering,
    ["core.neorgcmd.events.latex.render.enable"] = enable_rendering,
    ["core.neorgcmd.events.latex.render.disable"] = disable_rendering,
    ["core.neorgcmd.events.latex.render.toggle"] = toggle_rendering,
    ["core.autocommands.events.bufreadpost"] = render_latex,
    ["core.autocommands.events.bufwinenter"] = show_hidden,
    ["core.autocommands.events.cursormoved"] = clear_at_cursor,
    ["core.autocommands.events.textchanged"] = render_latex,
    ["core.autocommands.events.insertleave"] = render_latex,
    ["core.autocommands.events.colorscheme"] = function() 
        vim.schedule(function() compute_foreground(); if module.private.do_render then render_latex() end end) 
    end,
}

module.on_event = function(event)
    if event.referrer == "core.autocommands" and vim.bo[event.buffer].ft ~= "norg" then return end
    if event_handlers[event.type] then event_handlers[event.type]() end
end

module.events.subscribed = {
    ["core.autocommands"] = { bufreadpost = true, bufwinenter = true, cursormoved = true, textchanged = true, insertleave = true, colorscheme = true },
    ["core.neorgcmd"] = { ["latex.render.render"] = true, ["latex.render.enable"] = true, ["latex.render.disable"] = true, ["latex.render.toggle"] = true },
}

return module
