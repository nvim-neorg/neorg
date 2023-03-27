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
            module.required["core.integrations.treesitter"].execute_query([[
                (
                    (inline_math) @latex
                    (#offset! @latex 0 1 0 -1)
                )

                ; NOTE: We don't look for `@code` blocks here because those should be just that - code blocks, not rendered latex markup.
                (ranged_verbatim_tag (tag_name) @_tagname (tag_parameters .(tag_param) @_language) (ranged_verbatim_tag_content) @latex (#eq? @_tagname "embed") (#eq? @_language "latex")
                (ranged_verbatim_tag (tag_name) @_tagname (tag_parameters)? (ranged_verbatim_tag_content) @latex (#eq? @_tagname "math"))
            ]], function(query, id, node)
                if query.captures[id] ~= "latex" then
                    return
                end

                local latex_snippet = module.required["core.integrations.treesitter"].get_node_text(node, event.buf)

                local parsed = module.public.parse_latex(latex_snippet)

            end, event.buf)
        end,
    })
end

module.public = {
    -- Returns a handle to an image containing
    -- the rendered snippet.
    -- This handle can then be delegated to an external renderer.
    parse_latex = function(snippet)

    end,
}

module.config.public = {
    -- TODO: Documentation
    renderer = "core.integrations.hologram",
    dpi = 350,
}

return module
