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

        P(res)
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

        local function descend(node)
            local results = {}

            for child, _ in node:iter_children() do
                -- Add the node to the results
                if vim.tbl_contains(neorg_types, child:type()) then
                    local _res = {}

                    _res.c = {}
                    local _c = descend(child)
                    if #_c ~= 0 then
                        _res.c = _c
                    else
                        -- Delete c because nothing has been fetched
                        _res.c = nil
                    end

                    -- Add the pandoc type
                    local generator = module.config.public.pandoc_conversion[child:type()]
                    _res.t = generator.type

                    -- Use the child node instead for actual extraction
                    if generator.child then
                        child = module.private.get_child(child, generator.child)
                        if not child then
                            log.error("Error in fetching nodes, please check your pandoc public config")
                            return
                        end
                    end

                    -- Get node content
                    local content = ts_utils.get_node_text(child, bufnr)[1]
                    -- It's a terminal type, verify it's type and output text
                    local pandoc_type = module.config.public.pandoc_types[generator.type]
                    if type(pandoc_type) ~= "table" then
                        _res.c = content
                    end

                    -- Overrides the required subtypes with custom options
                    if generator.override then
                        _res.c = {}
                        for i, value in ipairs(generator.override) do
                            if type(value) == "table" and value[1] == "s" then
                                table.insert(_res.c, i, { content })
                            elseif value == "s" then
                                table.insert(_res.c, i, content)
                            else
                                table.insert(_res.c, i, value)
                            end
                        end
                    end

                    -- Add to results
                    table.insert(results, _res)
                else
                    -- Recursively extend the results with all childs
                    vim.list_extend(results, descend(child))
                end
            end

            return results
        end

        res = descend(root)

        return res
    end,

    get_child = function(node, child_type)
        for child, _ in node:iter_children() do
            if child:type() == child_type then
                return child
            end
        end
    end,
}
return module
