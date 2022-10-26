---@diagnostic disable: undefined-global
-- TODO: better colors
-- TODO: avoid code duplication.
require("neorg.modules.base")

local module = neorg.modules.create("core.execute")
local ts = require("nvim-treesitter.ts_utils")

module.setup = function()
    if vim.fn.isdirectory(module.public.tmpdir) == 0 then
        vim.fn.mkdir(module.public.tmpdir, "p")
    end
    return { success = true, requires = { "core.neorgcmd", "core.integrations.treesitter" } }
end

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        execute = {
            args = 1,
            subcommands = {
                view = { args=0, name="execute.view" },
                normal = { args=0, name="execute.normal" },
            }
        }
    })
end

module.config.public = {
    lang_cmds = {
        python = {cmd='python3 ${0}', type = 'interpreted'},
        lua = {cmd='lua ${0}', type='interpreted'},
        javascript = {cmd='node ${0}', type='interpreted'},
        bash = {cmd='bash ${0}', type='interpreted'},
        php = {cmd='php ${0}', type='interpreted'}
    },
}
module.config.private = {}

module.private = {
    buf = vim.api.nvim_get_current_buf(),
    ns = vim.api.nvim_create_namespace("execute"),
    code_block = {},
    interrupted = false,
    jobid = 0,
    temp_filename = '',


    virtual = {
        init = function()
            module.public.output = {}
            table.insert(module.public.output, {{"", 'Keyword'}})
            table.insert(module.public.output, {{"Result:", 'Keyword'}})

            local id = vim.api.nvim_buf_set_extmark(
                module.private.buf,
                module.private.ns,
                module.private.code_block['end'].row,
                module.private.code_block['end'].column,
                { virt_lines = module.public.output }
            )

            -- vim.api.nvim_create_autocmd('CursorMoved', {
                -- once = true,
                -- callback = function()
                    -- vim.api.nvim_buf_del_extmark(module.private.buf, module.private.ns, id)
                    -- module.private.interrupted = true
                    -- -- module.public.output = {}
                    -- vim.fn.delete(module.private.temp_filename)
                -- end
            -- })
            return id
        end,

        update = function(id)
            vim.api.nvim_buf_set_extmark(
                module.private.buf,
                module.private.ns,
                module.private.code_block['end'].row,
                0,
                { id=id, virt_lines = module.public.output }
            )
        end
    },
    normal = {
        line_set = 0,

        init = function()
            module.private.normal.line_set = module.private.code_block['end'].row + 1
            table.insert(module.public.output, '')
            table.insert(module.public.output, 'Result:')

            vim.api.nvim_buf_set_lines(
                module.private.buf,
                module.private.normal.line_set,
                module.private.normal.line_set,
                true,
                module.public.output
            )
            module.private.normal.line_set = module.private.normal.line_set + #module.public.output
        end,

        update = function(line)
            vim.api.nvim_buf_set_lines(
                module.private.buf,
                module.private.normal.line_set,
                module.private.normal.line_set,
                true,
                {line}
            )
            module.private.normal.line_set = module.private.normal.line_set + 1
        end
    },

    spawn = function(command)
        module.private.interrupted = false
        local mode = module.public.mode
        local id
        if mode == "view" then
            id = module.private.virtual.init()
        else
            module.private.normal.init()
        end

        module.private.jobid = vim.fn.jobstart(command, {
            stdout_buffered = false,

            -- TODO: check exit code conditions and colors
            on_stdout = function(_, data)
                if module.private.interrupted then
                    vim.fn.jobstop(module.private.jobid)
                    return
                end

                for _, line in ipairs(data) do
                    if line ~= "" then
                        if mode == "view" then
                            table.insert(module.public.output, {{line, 'Function'}})
                            module.private.virtual.update(id)
                        else
                            table.insert(module.public.output, line)
                            module.private.normal.update(line)
                        end
                    end
                end
            end,

            on_stderr = function(_, data)
                if module.private.interrupted then
                    vim.fn.jobstop(module.private.jobid)
                    return
                end

                for _, line in ipairs(data) do
                    if line ~= "" then
                        if mode == "view" then
                            table.insert(module.public.output, {{line, 'Error'}})
                            module.private.virtual.update(id)
                        else
                            table.insert(module.public.output, line)
                            module.private.normal.update(line)
                        end
                    end
                end

            end,

            on_exit = function()
                vim.fn.delete(module.private.temp_filename)
            end
        })
    end
}

module.public = {
    tmpdir = "/tmp/neorg-execute/",
    output = {},
    mode = "normal",

    base = function()
        local node = ts.get_node_at_cursor(0, true)
        local p = module.required["core.integrations.treesitter"].find_parent(node, "^ranged_tag$")

        -- TODO: Add checks here
        local code_block = module.required["core.integrations.treesitter"].get_tag_info(p, true)
        if not code_block then
            vim.pretty_print("Not inside a code block!")
            return
        end

        if code_block.name == "code" then
            module.private.code_block = code_block
            local ft = code_block.parameters[1]

            module.private.temp_filename = module.public.tmpdir
                .. code_block.start.row .. "_"
                .. code_block['end'].row
                .. "." .. ft

            local file = io.open(module.private.temp_filename, "w")
            if file == nil then return end
            file:write(table.concat(code_block.content, '\n'))
            file:close()

            local command = module.config.public.lang_cmds[ft]
            if not command then
                vim.notify("Language not supported currently!")
                return
            end
            command = command.cmd:gsub("${0}", module.private.temp_filename)

            module.private.spawn(command)
        end
    end,

    view = function()
        module.public.output = {}
        module.public.mode = "view"
        module.public.base()
    end,
    normal = function()
        module.public.output = {}
        module.public.mode = "normal"
        module.public.base()
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "execute.view" then
        vim.schedule(module.public.view)
    elseif event.split_type[2] == "execute.normal" then
        vim.schedule(module.public.normal)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["execute.view"] = true,
        ["execute.normal"] = true
    }
}

return module
