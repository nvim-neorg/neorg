require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.pandoc")
local Job = require("plenary.job")

module.setup = function()
    return { success = true, requires = { "core.integrations.treesitter" } }
end

module.public = {
    ---
    --- @param bufnr number
    --- @param format string
    export = function(bufnr, format)
        vim.validate({
            bufnr = { bufnr, "number" },
            format = { format, "string" },
        })
        local res = module.private.generate_pandoc(bufnr)

        -- Requiring json encoder/decoder
        local json = require("neorg.modules.core.integrations.pandoc.json")

        P(res)
        res = json.encode(res)

        -- Create file and start job
        -- os.execute("echo '" .. res .. "' > /tmp/neorg_gen_pandoc")
        -- Job
        --     :new({
        --         command = "pandoc",
        --         args = { "-f", "json", "-t", format, "/tmp/neorg_gen_pandoc" },
        --         on_stdout = function()
        --             os.remove("/tmp/neorg_gen_pandoc")
        --         end,
        --         on_stderr = function(_, return_val)
        --             log.error(return_val)
        --             os.remove("/tmp/neorg_gen_pandoc")
        --         end,
        --     })
        --     :start()
    end,
}

module.config.public = {
    pandoc_conversion = {
        -- Binding between the TS AST and pandoc's AST
        -- if the node is found in this list of nodes, it'll create a table in the current depth results like so:
        -- {
        --     t = type,
        --     c = {} -- or will extract it's content if the type is a terminal type
        -- }
        -- - if override, subtypes will be overriden by the values provided and the recursiveness will stop at current depth.
        --   - "s" is a special overriding word, which means: "Extract the current node text inside it"
        -- - if child, the type will be matched by the child instead of the actual parent
        ["paragraph"] = { type = "Para", override = { { "s" } } },
        ["heading1"] = { type = "Header", child = "paragraph_segment", override = { 1, "s", { "s" } } },
    },

    pandoc_types = {
        -- types (table):       provides the list of mandatory types
        -- subtypes (table):    the pandoc type is comprised of those types (must pick one of those)
        ["Header"] = { types = { "Int", "Attr", { "Inline" } } },
        ["Para"] = { types = { { "Inline" } } },
        ["Inline"] = { subtypes = { "Str", "Space" } },
        -- Terminal types
        ["Str"] = "string",
        ["Int"] = "number",
        ["Attr"] = "string",
        ["Space"] = "string",
    },
}

module.private = {
    generate_pandoc = function(bufnr)
        local res = {}
        res["pandoc-api-version"] = { 1, 22 }
        res.meta = {}
        res.blocks = {}

        -- Getting the root node from the bufnr
        local tree = vim.treesitter.get_parser(bufnr, "norg"):parse()[1]
        local root = tree:root()
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        local neorg_types = vim.tbl_keys(module.config.public.pandoc_conversion)

        local ref = res.blocks
        local function descend(node)
            for child, _ in node:iter_children() do
                if vim.tbl_contains(neorg_types, child:type()) then
                    local generator = module.config.public.pandoc_conversion[child:type()]

                    local content = ts_utils.get_node_text(child, bufnr)[1]
                    local inserted = { t = generator.type, c = { content } }
                    table.insert(ref, inserted)
                    ref = ref[#ref].c
                    descend(child)
                end

                -- Recursively constructs the table
                descend(child)
            end
        end

        descend(root)

        return res
    end,
}
return module
