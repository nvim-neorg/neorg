--[[
    file: Refactor-Module
    title: Move Files Fearlessly
    summary: A module that allows for moving files around without breaking links to or from the file
    internal: false
    ---

This module will provide a way to move files around without breaking existing links to or from the
file.

The aim is to provide a command to move them, but also to hook nvim's lsp handlers in order to
support moving files via something like Oil, which fires the correct events when files are moved.
--]]

local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.refactor")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.dirman",
            "core.neorgcmd",
            "core.link-tools",
        },
    }
end

local link_tools, dirman
module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        -- TODO: we should probably make a few different commands
        refactor = {
            min_args = 0, -- Tells neorgcmd that we want at least one argument for this command
            max_args = 1, -- Tells neorgcmd we want no more than one argument
            -- args = 0, -- Setting this variable instead would be the equivalent of min_args = 1 and max_args = 1
            name = "refactor",
        },
    })
    link_tools = module.required["core.link-tools"]
    dirman = module.required["core.dirman"]
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["refactor"] = true,
    },
}

module.on_event = function(event)
    if event.split_type[2] == "refactor" then
        module.private.test(event.content[1])
    end
end

module.public = {
    ---move the current file from one location to another, and update all the links to/from the file
    ---in the current workspace
    ---@param path any
    ---@param new_path any
    rename_file = function(path, new_path) end,

    -- NOTE: I want to use LSP text changes to update all the files in one go via a call
    -- to `vim.lsp.util.apply_workspace_edit()` where a WorkspaceEdit is in the form:
    -- `{ changes = { [fileuri]: TextEdit[] }[] }`

    ---fixes the links _in_ the file being moved
    ---@param current_path string
    ---@param new_path string
    fix_out_links = function(current_path, new_path)
        current_path = vim.fs.normalize(current_path)
        new_path = vim.fs.normalize(new_path)
        local current_dir = vim.fs.dirname(current_path)
        local current_ws = dirman.get_current_workspace()[2]
        -- current buffer links
        local links = link_tools.get_file_links_from_buf(0)
        for _, link in ipairs(links) do
            local path_text = link[1]
            if not string.match(path_text, "^%$") then
                -- NOTE: this could probably go into the dirman utils module or fs

                -- transform relative paths into a workspace relative path
                local ws_path = "$" .. string.gsub(current_dir .. "/" .. path_text, "^" .. current_ws, "")

                -- TODO: test that this works for paths with multiple "dir/../dir2/../"'s in it
                ws_path = string.gsub(ws_path, "/[^/]+/%.%./", "/")

                -- TODO: NEXT, setup a workspace edit for the current file and add the path edits
                -- that we find here into that table. Then return the table. This function will
                -- probably be called from `rename_file` which should keep track of all the edits,
                -- and merge them all together before applying them.
            end
        end
    end,
}

module.private = {
    ---just a function that's used to test whatever I'm working on
    test = function(file)
        module.public.fix_out_links("~/notes/tools/index.norg", "~/notes/tools/test.norg")
    end,
}

return module
