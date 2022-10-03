--[[
    File: Nvim-Compe
    Title: Integrating Neorg with `nvim-compe`
    Summary: A module for integrating nvim-compe with Neorg.
    Internal: true
    ---
A module for integrating nvim-compe with Neorg.
Works with core.norg.completion to provide intelligent completions.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.nvim-compe")

-- Define some private data that's not supposed to be seen
module.private = {
    source = {},
    compe = {},

    completions = {},
}

module.load = function()
    -- Code to test the existence of nvim-compe
    local success, compe = pcall(require, "compe")

    if not success then
        log.fatal("nvim-compe not found, aborting...")
        return
    end

    module.private.compe = compe
end

---@class core.integrations.nvim-compe
module.public = {
    ---@param user_data table #A table of user data to supply to the source upon creation
    create_source = function(user_data)
        user_data = user_data or {}

        local data = {
            name = "[Neorg]",
            priority = 998,
            sort = false,
            dup = 0,
        }

        data = vim.tbl_deep_extend("force", data, user_data)

        -- Define functions for nvim-compe
        module.private.source.new = function()
            return setmetatable({}, { __index = module.private.source })
        end

        -- Return metadata for nvim-compe to use
        module.private.source.get_metadata = function()
            return {
                priority = data.priority,
                sort = data.sort,
                dup = data.dup,
                filetypes = { "norg" },
                menu = data.name,
            }
        end

        -- Used to determine whether or not to provide completions, simply invokes the public determine function
        module.private.source.determine = function(_, context)
            return module.public.determine(context)
        end

        -- Used to actually provide completions, simply invokes the public sibling function
        module.private.source.complete = function(_, context)
            module.public.complete(context)
        end

        -- Invoked whenever a completion is confirmed, calls the public confirm() function
        module.private.source.confirm = function(_, context)
            module.public.confirm(context)
        end

        -- Actually register the nvim-compe source
        module.private.compe.register_source("neorg", module.private.source)
    end,

    --- Looks at the cursor position and tries to determine whether we should provide any completions
    ---@param context table #The context provided by nvim-compe
    determine = function(context)
        -- Abstract away the context to a completion engine agnostic format
        local abstracted_context = module.public.create_abstracted_context(context)

        -- Update the current completion cache with the data returned by core.norg.completion
        module.private.completion_cache = module.public.invoke_completion_engine(abstracted_context)

        -- If we haven't returned any items to complete via that function then return an empty table,
        -- symbolizing a lack of completions
        if vim.tbl_isempty(module.private.completion_cache.items) then
            return {}
        end

        -- If the current completion that was found has a pre() function then invoke that
        if module.private.completion_cache.options.pre then
            module.private.completion_cache.options.pre(abstracted_context)
        end

        -- Reverse the current line, this is used for a reverse find() call
        local reversed = vim.trim(context.before_line):reverse()
        -- Find any occurrence of whitespace
        local last_whitespace = reversed:find("%s")

        --[[
            This bit is a bit crazy, however here's the gist of it:
            It checks the current cursor position and the last occurrence of whitespace in the string to provide completions
            even if a part of that completion is already present. Say we have:
            @
            Compe would have no problem with this and would provide completions instantly, but say we have (| means the current cursor pos):
            @t|ab
            And i try pressing C to edit till the end of the line, I'm then left with:
            @t
            If I were to try typing here I wouldn't get any completions, because compe wouldn't understand that @t is part of the completion.
            This below bit of code makes sure that it *does* understand and that it *does* detect properly.
        --]]
        last_whitespace = last_whitespace and last_whitespace - 1
            or (function()
                local found = module.private.completion_cache.options.completion_start
                    and reversed:find(module.private.completion_cache.options.completion_start)
                return found and found - 1 or 0
            end)()

        return { keyword_pattern_offset = 0, trigger_character_offset = context.col - last_whitespace }
    end,

    --- Once the completion candidates have been collected from the determine() function it's time to display them
    ---@param context table #A context as provided by nvim-compe
    complete = function(context)
        -- If the completion cache is empty for some reason then don't do anything
        if vim.tbl_isempty(module.private.completion_cache.items) then
            return
        end

        -- Grab a copy of the completions (important, because if it's not copied then values get overwritten)
        local completions = vim.deepcopy(module.private.completion_cache.items)

        -- Go through each element and convert it into a format that nvim-compe understands
        for index, element in ipairs(completions) do
            completions[index] = { word = element, kind = module.private.completion_cache.options.type }
        end

        -- Display the completions
        context.callback({
            items = completions,
        })
    end,

    ---@param context table #A context as provided by nvim-compe
    confirm = function()
        -- If the defined completion has a post function then invoke it
        if module.private.completion_cache.options.post then
            module.private.completion_cache.options.post()
        end

        -- Reset the completion cache
        module.private.completion_cache = {}
    end,

    --- Returns a new context based off of nvim-compe's "proprietary" context and converts it into a universal context
    ---@param context table #A context as provided by nvim-compe
    create_abstracted_context = function(context)
        return {
            start_offset = context.start_offset,
            char = context.char,
            before_char = context.before_char,
            line = context.before_line,
            column = context.col,
            buffer = context.bufnr,
            line_number = context.lnum,
            previous_context = {
                line = context.prev_context.before_line,
                column = context.prev_context.col,
                start_offset = context.prev_context.start_offset,
            },
            full_line = context.line,
        }
    end,
}

return module
