require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.pandoc")
local Job = require("plenary.job")

module.setup = function()
    return { success = true, requires = { "core.integrations.treesitter" } }
end

module.config.public = {
    pandoc_conversion = {
        -- break_as: the content table will be
        ["paragraph"] = { type = "Para" },
        ["heading1"] = {
            subtree = {
                ["paragraph_segment"] = { position = 1, type = "Header" },
            },
        },
    },

    pandoc_types = {
        ["Header"] = { types = { "Int", "Attr", { "Inline" } } },
        ["Para"] = { types = { { "Inline" } } },
        ["Inline"] = { subtypes = { "Str", "Space" }, force = "Str" },
        ["Str"] = "string",
        ["Int"] = "number",
        ["Attr"] = "string",
        ["Space"] = "string",
    },
}

module.public = {
    ---
    --- @param bufnr number
    --- @param format string
    export = function(bufnr, format)
        vim.validate({
            bufnr = { bufnr, "number" },
            format = { format, "string" },
        })
        local res = module.private.generate_pandoc(bufnr, format)

        -- Requiring json encoder/decoder
        local json = require("neorg.modules.core.integrations.pandoc.json")

        res = json.encode(res)
        P(res)

        -- Create file and start job
        os.execute("echo '" .. res .. "' > /tmp/neorg_gen_pandoc")
        Job
            :new({
                command = "pandoc",
                args = { "-f", "json", "-t", format, "/tmp/neorg_gen_pandoc" },
                on_stdout = function()
                    os.remove("/tmp/neorg_gen_pandoc")
                end,
                on_stderr = function(_, return_val)
                    log.error(return_val)
                    os.remove("/tmp/neorg_gen_pandoc")
                end,
            })
            :start()
    end,
}

module.private = {
    generate_pandoc = function(bufnr, format)
        local res = {}
        res["pandoc-api-version"] = { 1, 22 }
        res.meta = {}
        res.blocks = {}

        -- Getting the root node from the bufnr
        local tree = vim.treesitter.get_parser(bufnr, "norg"):parse()[1]
        local root = tree:root()
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        local neorg_types = vim.tbl_keys(module.config.public.pandoc_conversion)

        local function descend(node)
            for child, _ in node:iter_children() do
                if vim.tbl_contains(neorg_types, child:type()) then
                    local generator = module.config.public.pandoc_conversion[child:type()]

                    local content
                    if generator.parent then
                        -- Depends of his parent to export
                        local parent = child:parent()
                        if parent:type() == generator.parent then
                            content = ts_utils.get_node_text(child, bufnr)[1]
                        end

                        local values

                        if generator.break_as then
                            values = { t = generator.break_as, c = content }
                        else
                            values = { content }
                        end

                        if generator.position then
                            content = { generator.position, content, values }
                        end
                    else
                        content = ts_utils.get_node_text(child, bufnr)[1]
                    end

                    table.insert(res.blocks, { t = generator.type, c = content })
                end
                descend(child)
            end
        end

        descend(root)

        return res
    end,
}
return module
