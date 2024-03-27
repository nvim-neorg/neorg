local neorg = require("neorg")
local modules = neorg.modules

local module = modules.create("core.todo-introspector")

module.private = {
    namespace = vim.api.nvim_create_namespace("neorg/todo-introspector"),

    --- List of active buffers
    buffers = {},
}

-- NOTE(vhyrro): This module serves as a temporary proof of concept.
-- We will want to add a plethora of customizability options after the base behaviour is implemented.
module.config.public = {}

module.setup = function()
    return {
        success = true,
        requires = { "core.integrations.treesitter" },
    }
end

module.load = function()
    vim.api.nvim_create_autocmd("Filetype", {
        pattern = "norg",
        desc = "Attaches the TODO introspector to any Norg buffer.",
        callback = function(ev)
            local buf = ev.buf

            if module.private.buffers[buf] then
                return
            end

            module.private.buffers[buf] = true
            module.public.attach_introspector(buf)
        end,
    })
end

--- Attaches the introspector to a given Norg buffer.
--- Errors if the target buffer is not a Norg buffer.
---@param buffer number #The buffer ID to attach to.
function module.public.attach_introspector(buffer)
    if not vim.api.nvim_buf_is_valid(buffer) or vim.bo[buffer].filetype ~= "norg" then
        error(string.format("Could not attach to buffer %d, buffer is not a norg file!", buffer))
    end

    local language_tree = vim.treesitter.get_parser(buffer, "norg")
    language_tree:parse(true)

    vim.api.nvim_buf_attach(buffer, false, {
        on_lines = function(_, buf, _, first)
            ---@type TSNode?
            local node = module.required["core.integrations.treesitter"].get_first_node_on_line(buf, first)

            assert(node)

            ---@type TSNode?
            local parent = node

            while parent do
                local child = parent:named_child(1)

                if child and child:type() == "detached_modifier_extension" then
                    module.public.perform_introspection(buffer, node)
                    break
                end

                parent = parent:parent()
            end
        end,
        on_detach = function()
            module.private.buffers[buffer] = nil
        end,
    })
end

--- 
---@param buffer number
---@param node TSNode
function module.public.perform_introspection(buffer, node)
    assert(false)
end

return module
