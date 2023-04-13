local module = neorg.modules.create("core.latex.renderer")

module.setup = function()
    return {
        requires = { "core.integrations.treesitter" },
    }
end

module.load = function()
    vim.api.nvim_create_autocmd("BufWinEnter", {
        pattern = "*.norg",
        callback = function(event)
            module.required["core.integrations.treesitter"].execute_query(
                [[
                (
                    (inline_math) @latex
                    (#offset! @latex 0 1 0 -1)
                )

                ; NOTE: We don't look for `@code` blocks here because those should be just that - code blocks, not rendered latex markup.
                (ranged_verbatim_tag (tag_name) @_tagname (tag_parameters .(tag_param) @_language) (ranged_verbatim_tag_content) @latex (#eq? @_tagname "embed") (#eq? @_language "latex"))
                (ranged_verbatim_tag (tag_name) @_tagname (tag_parameters)? (ranged_verbatim_tag_content) @latex (#eq? @_tagname "math"))
            ]],
                function(query, id, node)
                    if query.captures[id] ~= "latex" then
                        return
                    end

                    local latex_snippet = module.required["core.integrations.treesitter"].get_node_text(node, event.buf)

                    local png_location = module.public.parse_latex(latex_snippet)

                    local renderer = neorg.modules.get_module(module.config.public.renderer)

                    if not renderer then
                        return
                    end

                    renderer.render(
                        event.buf,
                        png_location,
                        module.required["core.integrations.treesitter"].get_node_range(node)
                    )
                end,
                event.buf
            )
        end,
    })
end

module.public = {
    create_latex_document = function(snippet)
        local tempname = vim.fn.tempname()

        local tempfile = io.open(tempname, "w")

        if not tempfile then
            return
        end

        local content = table.concat(
            {
                "\\documentclass[6pt]{standalone}",
                "\\usepackage{amsmath}",
                "\\usepackage{amssymb}",
                "\\usepackage{graphicx}",
                "\\begin{document}",
                snippet,
                "\\end{document}",
            },
            "\n"
        )

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
}

module.config.public = {
    -- TODO: Documentation
    renderer = "core.integrations.hologram",
    dpi = 350,
}

return module
