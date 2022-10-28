---@diagnostic disable: undefined-global
-- TODO: better colors
-- TODO: avoid code duplication.
require("neorg.modules.base")
local spinner = require("neorg.modules.core.execute.spinner")

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

module.config.public = require("neorg.modules.core.execute.config")
module.config.private = {}

module.private = {
    tasks = {},

    ns = vim.api.nvim_create_namespace("execute"),

    virtual = {
        init = function(id)
            local curr_task = module.private.tasks[id]
            curr_task.spinner = spinner.start(curr_task, module.private.ns)

            --> NICE: nice

            table.insert(curr_task.output, {{"", 'Keyword'}})
            table.insert(curr_task.output, {{"Result:", 'Keyword'}})

            -- module.private.tasks[id]
            vim.api.nvim_buf_set_extmark(
                curr_task.buf,
                module.private.ns,
                curr_task.code_block['end'].row,
                0,
                { id=id, virt_lines = curr_task.output }
            )
            return id
        end,

        update = function(id)
            local curr_task = module.private.tasks[id]

            vim.api.nvim_buf_set_extmark(
                curr_task.buf,
                module.private.ns,
                curr_task.code_block['end'].row,
                0,
                { id=id, virt_lines = curr_task.output }
            )
        end
    },

    normal = {
        init = function(id)
            local curr_task = module.private.tasks[id]
            curr_task.spinner = spinner.start(curr_task, module.private.ns)

            table.insert(curr_task.output, '')
            table.insert(curr_task.output, 'Result:')

            for i, line in ipairs(curr_task.output) do
                vim.pretty_print(line)
                vim.api.nvim_buf_set_lines(
                    curr_task.buf,
                    curr_task.code_block['end'].row + i,
                    curr_task.code_block['end'].row + i,
                    true,
                    {line}
                )
            end
        end,

        update = function(id, line)
            local curr_task = module.private.tasks[id]
            vim.api.nvim_buf_set_lines(
                curr_task.buf,
                curr_task.code_block['end'].row + #curr_task.output,
                curr_task.code_block['end'].row + #curr_task.output,
                true,
                {line}
            )
        end
    },

    init = function()
        local id = vim.api.nvim_buf_set_extmark(
            0, -- NICE: check if errors
            module.private.ns,
            0, 0, {}
        )

        module.private.tasks[id] = {
            buf = vim.api.nvim_get_current_buf(),
            output = {},
            interrupted = false,
            jobid = nil,
            temp_filename = nil,
            code_block = {},
            spinner = nil
        }

        return id
    end,

    spawn = function(id, command)
        -- module.private.interrupted = false
        local mode = module.public.mode

        if mode == "view" then
            module.private.virtual.init(id)
        else
            module.private.normal.init(id)
        end

        module.private.tasks[id].jobid = vim.fn.jobstart(command, {
            stdout_buffered = false,

            -- TODO: check exit code conditions and colors
            on_stdout = function(_, data)
                if module.private.tasks[id].interrupted then
                    vim.fn.jobstop(module.private.tasks[id].jobid)
                    return
                end

                for _, line in ipairs(data) do
                    if line ~= "" then
                        if mode == "view" then
                            table.insert(module.private.tasks[id].output, {{line, 'Function'}})
                            module.private.virtual.update(id)
                        else
                            table.insert(module.private.tasks[id].output, line)
                            module.private.normal.update(id, line)
                        end
                    end
                end
            end,

            on_stderr = function(_, data)
                if module.private.tasks[id].interrupted then
                    vim.fn.jobstop(module.private.tasks[id].jobid)
                    return
                end

                for _, line in ipairs(data) do
                    if line ~= "" then
                        if mode == "view" then
                            table.insert(module.public.tasks[id].output, {{line, 'Error'}})
                            module.private.virtual.update(id)
                        else
                            table.insert(module.public.tasks[id].output, line)
                            module.private.normal.update(id, line)
                        end
                    end
                end

            end,

            on_exit = function()
                spinner.shut(module.private.tasks[id].spinner, module.private.ns)
                vim.fn.delete(module.private.tasks[id].temp_filename)
            end
        })
    end
}

module.public = {
    tmpdir = "/tmp/neorg-execute/",
    mode = "normal",

    base = function(id)
        local node = ts.get_node_at_cursor(0, true)
        local p = module.required["core.integrations.treesitter"].find_parent(node, "^ranged_tag$")

        -- TODO: Add checks here
        local code_block = module.required["core.integrations.treesitter"].get_tag_info(p, true)
        if not code_block then
            vim.notify("Not inside a code block!")
            return
        end

        if code_block.name == "code" then
            module.private.tasks[id]['code_block'] = code_block
            -- FIX: temp fix remove this!
            code_block['parameters'] = vim.split(code_block['parameters'][1], ' ')
            local ft = code_block.parameters[1]

            module.private.tasks[id].temp_filename = module.public.tmpdir
                .. id
                -- .. code_block.start.row .. "_"
                -- .. code_block['end'].row
                .. "." .. ft

            local lang_cfg = module.config.public.lang_cmds[ft]
            if not lang_cfg then
                vim.notify("Language not supported currently!")
                return
            end

            local file = io.open(module.private.tasks[id].temp_filename, "w")
            -- TODO: better error.
            if file == nil then return end

            local file_content = table.concat(code_block.content, '\n')
            if not vim.tbl_contains(code_block.parameters, ":main") and lang_cfg.type == "compiled" then
                local c = lang_cfg.main_wrap
                file_content = c:gsub("${1}", file_content)
            end
            file:write(file_content)
            file:close()

            local command = lang_cfg.cmd:gsub("${0}", module.private.tasks[id].temp_filename)
            module.private.spawn(id, command)
        end
    end,

    view = function()
        module.public.mode = "view"
        local id = module.private.init()
        module.public.base(id)
    end,
    normal = function()
        module.public.mode = "normal"
        local id = module.private.init()
        module.public.base(id)
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
