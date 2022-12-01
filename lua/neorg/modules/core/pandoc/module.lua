require("neorg.modules.base")

local module = neorg.modules.create("core.pandoc")
local log = require("neorg.external.log")

module.setup = function()
    if vim.fn.executable("pandoc") == 0 then
        log.error(
            "Unable to load `core.pandoc`: no `pandoc` executable found on the system! Be sure to install it through your favourite package manager."
        )

        return {
            success = false,
        }
    end

    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.load = function()
    neorg.modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            pandoc = {
                args = 1,
                condition = "norg",

                subcommands = {
                    export = {
                        min_args = 1,
                        name = "pandoc.export",
                        complete = {
                            module.config.public.formats,
                        },
                    },
                    list = {
                        args = 0,
                        name = "pandoc.list",
                    },
                    json = {
                        args = 0,
                        name = "pandoc.json",
                    },
                },
            },
        })
    end)

    -- Get all possible output formats
    vim.fn.jobstart({ "pandoc", "--list-output-formats" }, {
        on_stdout = function(_, data)
            if data[#data] == "" then
                table.remove(data)
            end

            vim.list_extend(module.config.public.formats, data)
        end,
        stdout_buffered = true,
    })
end

module.public = {
    ---Run a pandoc command using installed pandoc binary and return its result. Returns nil if arguments are empty or pandoc command failed.
    ---@param cmd string All desired arguments passed to pandoc
    ---@return string|nil stdout Command output
    pandoc_cmd = function(cmd)
        if not cmd then
            return nil
        end

        local res = io.popen("pandoc " .. cmd)

        if not res then
            log.error("Error running pandoc")
            return nil
        end

        return res:read("*a")
    end,

    --- Converts all nodes in the current buffer into an intermediary flat representation
    ---@param buffer number #The buffer number to convert
    ---@return table #A flat representation of the nodes in the buffer
    convert = function(buffer)
        local tree = vim.treesitter.get_parser(buffer, "norg"):parse()[1]
        local ts = module.required["core.integrations.treesitter"]

        local flat_table = {}

        local function create_identifier(prefix, title)
            return table.concat({ prefix, "-", title:gsub("%s", ""):lower() })
        end

        local function word(node)
            return {
                t = "Str",
                c = ts.get_node_text(node),
            }
        end

        ---@param level number
        local function heading(node, level)
            local title = node:named_child(1) and ts.get_node_text(node:named_child(1)) or ""

            return {
                t = "Header",
                c = {
                    level,
                    { create_identifier(table.concat({ "heading", tostring(level) }), title), {}, {} },
                },
            }
        end

        -------------------------------

        local function match_func(node)
            local wrap = neorg.lib.wrap

            local output = neorg.lib.match(node:type())({
                ["heading1"] = wrap(heading, node, 1),
                ["heading2"] = wrap(heading, node, 2),
                ["heading3"] = wrap(heading, node, 3),
                ["heading4"] = wrap(heading, node, 4),
                ["heading5"] = wrap(heading, node, 5),
                ["heading6"] = wrap(heading, node, 6),

                ["_space"] = {
                    t = "Space",
                },
                ["_word"] = wrap(word, node),

                ["_line_break"] = "line_break",
                ["_paragraph_break"] = "paragraph_break",
            })

            if output then
                table.insert(flat_table, output)
                return false
            end
        end

        ts.tree_map_rec(match_func, tree)

        table.insert(flat_table, "eof")

        local norg_meta = ts.get_document_metadata(buffer)
        local meta = {}

        for key, value in pairs(norg_meta) do
            meta[key] = {
                t = "MetaInlines",
                c = { { t = "Str", c = value } },
            }
        end

        return {
            ["pandoc-api-version"] = { 1, 22, 2, 1 },
            meta = meta,
            blocks = flat_table,
        }
    end,
}

module.config.public = {
    formats = {},
}

module.on_event = function(event)
    neorg.lib.match(event.type)({
        ["core.neorgcmd.events.pandoc.export"] = function()
            vim.notify(vim.inspect(module.public.convert(event.buffer)))
        end,
        ["core.neorgcmd.events.pandoc.list"] = function()
            vim.notify(table.concat(module.config.public.formats, "\n"))
        end,
        ["core.neorgcmd.events.pandoc.json"] = function()
            vim.pretty_print(module.public.convert(event.buffer))
        end,
    })
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["pandoc.export"] = true,
        ["pandoc.list"] = true,
        ["pandoc.json"] = true,
    },
}

return module
