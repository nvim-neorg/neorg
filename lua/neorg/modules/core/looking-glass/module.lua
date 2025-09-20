--[[
    file: Looking-Glass
    title: Code Blocks + Superpowers
    description: The `core.looking-glass` module magnifies code blocks and allows you to edit them in a separate buffer.
    summary: Allows for editing of code blocks within a separate buffer.
    embed: https://user-images.githubusercontent.com/76052559/216782314-5d82907f-ea6c-44f9-9bd8-1675f1849358.gif
    ---
The looking glass module provides a simple way to edit code blocks in an external buffer,
which allows LSPs and other language-specific tools to kick in.

If you would like LSP features in code blocks without having to magnify, you can use
[`core.integrations.otter`](@core.integrations.otter).

## Keybinds

This module exposes the following keybinds (see [`core.keybinds`](@core.keybinds) for instructions on
mapping them):

- `neorg.looking-glass.magnify-code-block` - magnify the code block under the cursor
--]]

local neorg = require("neorg.core")
local modules, utils = neorg.modules, neorg.utils

local module = modules.create("core.looking-glass")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.ui",
        },
    }
end

module.load = function()
    vim.keymap.set("", "<Plug>(neorg.looking-glass.magnify-code-block)", module.public.magnify_code_block)
end

---@class core.looking-glass
module.public = {
    sync_text_segment = function(source, source_window, source_start, source_end, target, target_window)
        -- Create a unique but deterministic namespace name for the code block
        local namespace = vim.api.nvim_create_namespace(
            "neorg/code-block-" .. tostring(source) .. tostring(source_start.row) .. tostring(source_end.row)
        )

        -- Clear any leftover extmarks
        vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)

        -- Create two extmarks, one at the beginning of the code block and one at the end.
        -- This lets us track size changes of the code block (shrinking and enlarging)
        local start_extmark = vim.api.nvim_buf_set_extmark(source, namespace, source_start.row, source_start.column, {})
        local end_extmark = vim.api.nvim_buf_set_extmark(source, namespace, source_end.row, source_end.column, {})

        -- This autocommand handles the synchronization from the source buffer to the target buffer
        -- (from the code block to the split)
        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
            buffer = source,
            callback = function()
                if not vim.api.nvim_buf_is_loaded(target) or not vim.api.nvim_buf_is_loaded(source) then
                    return true
                end

                local cursor_pos = vim.api.nvim_win_get_cursor(source_window)

                if vim.api.nvim_get_current_buf() ~= source then
                    return
                end

                -- Get the positions of both the extmarks (this has to be in the schedule function else it returns
                -- outdated information).
                local extmark_begin = vim.api.nvim_buf_get_extmark_by_id(source, namespace, start_extmark, {})
                local extmark_end = vim.api.nvim_buf_get_extmark_by_id(source, namespace, end_extmark, {})

                -- Both extmarks will have the same row if the user deletes the whole code block.
                -- In other words, this is a method to detect when a code block has been deleted.
                if extmark_end[1] == extmark_begin[1] then
                    vim.api.nvim_buf_delete(target, { force = true })
                    vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)
                    return true
                end

                -- Make sure that the cursor is within bounds of the code block
                if cursor_pos[1] > extmark_begin[1] and cursor_pos[1] <= (extmark_end[1] + 1) then
                    -- For extra information grab the current node under the cursor
                    local current_node = vim.treesitter.get_node({ bufnr = source, ignore_injections = true })

                    if not current_node then
                        vim.api.nvim_buf_delete(target, { force = true })
                        vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)
                        return true
                    end

                    -- If we are within bounds of the code block but the current node type is not part of a ranged
                    -- tag then it means the user malformed the code block in some way and we should bail
                    if
                        not module.required["core.integrations.treesitter"].find_parent(
                            current_node,
                            "^ranged_verbatim_tag.*"
                        )
                    then
                        vim.api.nvim_buf_delete(target, { force = true })
                        vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)
                        return true
                    end

                    local lines = vim.api.nvim_buf_get_lines(source, extmark_begin[1] + 1, extmark_end[1], true)

                    for i, line in ipairs(lines) do
                        lines[i] = line:sub(extmark_begin[2] + 1)
                    end

                    -- Now that we have full information that we are in fact in a valid code block
                    -- take the lines from within the code block and put them in the buffer
                    vim.api.nvim_buf_set_lines(target, 0, -1, false, lines)

                    local target_line_count = vim.api.nvim_buf_line_count(target)

                    -- Set the cursor in the target window to the place the text is being changed.
                    -- Useful to keep up with long ranges of text.
                    --
                    -- This check exists as sometimes the cursor position can be larger than the size of the
                    -- target buffer which causes errors.
                    if cursor_pos[1] - extmark_begin[1] > target_line_count then
                        vim.api.nvim_win_set_cursor(target_window, { target_line_count, cursor_pos[2] })
                    else
                        -- Here we subtract the beginning extmark's row position from the current cursor position
                        -- in order to create an offset that can be applied to the target buffer.
                        vim.api.nvim_win_set_cursor(
                            target_window,
                            { cursor_pos[1] - extmark_begin[1] - 1, cursor_pos[2] }
                        )
                    end
                end
            end,
        })

        -- Target -> source binding
        -- This binding is much simpler, as it captures changes from the vertical split and applies them
        -- to the source code block.
        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
            buffer = target,
            callback = vim.schedule_wrap(function() -- Schedule wrap is needed for up-to-date extmark information
                local cursor_pos = vim.api.nvim_win_get_cursor(0)

                local extmark_begin = vim.api.nvim_buf_get_extmark_by_id(source, namespace, start_extmark, {})
                local extmark_end = vim.api.nvim_buf_get_extmark_by_id(source, namespace, end_extmark, {})

                local lines = vim.api.nvim_buf_get_lines(target, 0, -1, true)

                for i, line in ipairs(lines) do
                    lines[i] = string.rep(" ", extmark_begin[2]) .. line
                end

                vim.api.nvim_buf_set_lines(source, extmark_begin[1] + 1, extmark_end[1], true, lines)

                vim.api.nvim_win_set_cursor(
                    source_window,
                    { cursor_pos[1] + 1 + extmark_begin[1], cursor_pos[2] + extmark_begin[2] }
                )
            end),
        })

        -- For when the user closes the target buffer or vertical split.
        vim.api.nvim_create_autocmd({ "BufDelete", "WinClosed" }, {
            buffer = target,
            once = true,
            callback = function()
                pcall(vim.api.nvim_buf_delete, target, { force = true })
                vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)
            end,
        })
    end,

    magnify_code_block = function()
        local buffer = vim.api.nvim_get_current_buf()
        local window = vim.api.nvim_get_current_win()

        local query = utils.ts_parse_query(
            "norg",
            [[
            (ranged_verbatim_tag
                name: (tag_name) @_name
                (#any-of? @_name "code" "embed")) @tag
        ]]
        )

        local document_root = module.required["core.integrations.treesitter"].get_document_root(buffer)

        --- Table containing information about the code block that is potentially under the cursor
        local code_block_info

        do
            local cursor_pos = vim.api.nvim_win_get_cursor(window)

            for id, node in query:iter_captures(document_root, buffer, cursor_pos[1] - 1, cursor_pos[1]) do
                local capture = query.captures[id]

                if capture == "tag" then
                    local tag_info = module.required["core.integrations.treesitter"].get_tag_info(node)

                    if not tag_info then
                        utils.notify("Unable to magnify current code block :(", vim.log.levels.WARN)
                        return
                    end

                    code_block_info = tag_info
                end
            end
        end

        -- If the query above failed then we know that the user isn't under a code block
        if not code_block_info then
            utils.notify("No code block found under cursor!", vim.log.levels.WARN)
            return
        end

        -- TODO: Make the vsplit location configurable (i.e. whether it spawns on the left or the right)
        local vsplit = module.required["core.ui"].create_vsplit(
            "code-block-" .. tostring(code_block_info.start.row) .. tostring(code_block_info["end"].row), -- This is done to make the name of the vsplit unique
            true,
            {
                filetype = (code_block_info.parameters[1] or "none"),
            },
            { split = "left" }
        )

        if not vsplit then
            utils.notify(
                "Unable to magnify current code block because our split didn't want to open :(",
                vim.log.levels.WARN
            )
            return
        end

        -- Set the content of the target buffer to the content of the code block (initial synchronization)
        vim.api.nvim_buf_set_lines(vsplit, 0, -1, true, code_block_info.content)

        -- iterate over attributes and find the last row of them.
        local last_attribute = nil
        if code_block_info.attributes then
            last_attribute = code_block_info.attributes[1]

            for _, v in ipairs(code_block_info.attributes) do
                if v["end"].row > last_attribute["end"].row then
                    last_attribute = v
                end
            end
        end

        local start = last_attribute and last_attribute["end"] or code_block_info.start

        module.public.sync_text_segment(
            buffer,
            window,
            start,
            code_block_info["end"],
            vsplit,
            vim.api.nvim_get_current_win()
        )
    end,
}

return module
