--[[
    File: Core-Highlights
    Title: Neorg module for managing highlight groups
    Summary: Manages your highlight groups with this module.
    Internal: true
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.highlights")

--[[
    Nested trees concatenate
    So:
        tag = { begin = "+@comment" }
    matches the highlight group:
        @neorg.tag.begin
    and converts into the command:
        highlight! link @neorg.tag.begin @comment
--]]
module.config.public = {
    -- The TS highlights for each Neorg type
    highlights = {
        selection_window = {
            -- The + tells neorg to link to an existing hl
            -- You may also supply any arguments you would to :highlight here
            -- Example: ["heading"] = "gui=underline",
            heading = "+@annotation",
            arrow = "+@none",
            key = "+@namespace",
            keyname = "+@constant",
            nestedkeyname = "+@string",
        },

        tags = {
            ranged_verbatim = {
                begin = "+@keyword",

                ["end"] = "+@keyword",

                name = {
                    [""] = "+@none",
                    delimiter = "+@none",
                    word = "+@keyword",
                },

                parameters = "+@type",

                document_meta = {
                    key = "+@field",
                    value = "+@string",
                    trailing = "+@repeat",
                    title = "+@text.title",
                    description = "+@label",
                    authors = "+@annotation",
                    categories = "+@keyword",
                    created = "+@float",
                    updated = "+@float",
                    version = "+@float",

                    object = {
                        bracket = "+@punctuation.bracket",
                    },

                    array = {
                        bracket = "+@punctuation.bracket",
                        value = "+@none",
                    },
                },
            },

            carryover = {
                begin = "+@label",

                name = {
                    [""] = "+@none",
                    word = "+@label",
                    delimiter = "+@none",
                },

                parameters = "+@string",
            },

            comment = {
                content = "+@comment",
            },
        },

        headings = {
            ["1"] = {
                title = "+@attribute",
                prefix = "+@attribute",
            },
            ["2"] = {
                title = "+@label",
                prefix = "+@label",
            },
            ["3"] = {
                title = "+@constant",
                prefix = "+@constant",
            },
            ["4"] = {
                title = "+@string",
                prefix = "+@string",
            },
            ["5"] = {
                title = "+@label",
                prefix = "+@label",
            },
            ["6"] = {
                title = "+@constructor",
                prefix = "+@constructor",
            },
        },

        error = "+@error",

        markers = {
            prefix = "+@label",
            title = "+@none",
        },

        definitions = {
            prefix = "+@punctuation.delimiter",
            suffix = "+@punctuation.delimiter",
            title = "+@text.strong",
            content = "+@text.emphasis",
        },

        footnotes = {
            prefix = "+@punctuation.delimiter",
            suffix = "+@punctuation.delimiter",
            title = "+@text.strong",
            content = "+@text.emphasis",
        },

        todo_items = {
            undone = {
                ["1"] = { [""] = "+@punctuation.delimiter", content = "+@none" },
                ["2"] = { [""] = "+@punctuation.delimiter", content = "+@none" },
                ["3"] = { [""] = "+@punctuation.delimiter", content = "+@none" },
                ["4"] = { [""] = "+@punctuation.delimiter", content = "+@none" },
                ["5"] = { [""] = "+@punctuation.delimiter", content = "+@none" },
                ["6"] = { [""] = "+@punctuation.delimiter", content = "+@none" },
            },
            pending = {
                ["1"] = { [""] = "+@namespace", content = "+@none" },
                ["2"] = { [""] = "+@namespace", content = "+@none" },
                ["3"] = { [""] = "+@namespace", content = "+@none" },
                ["4"] = { [""] = "+@namespace", content = "+@none" },
                ["5"] = { [""] = "+@namespace", content = "+@none" },
                ["6"] = { [""] = "+@namespace", content = "+@none" },
            },
            done = {
                ["1"] = { [""] = "+@string", content = "+@none" },
                ["2"] = { [""] = "+@string", content = "+@none" },
                ["3"] = { [""] = "+@string", content = "+@none" },
                ["4"] = { [""] = "+@string", content = "+@none" },
                ["5"] = { [""] = "+@string", content = "+@none" },
                ["6"] = { [""] = "+@string", content = "+@none" },
            },
            on_hold = {
                ["1"] = { [""] = "+@text.note", content = "+@none" },
                ["2"] = { [""] = "+@text.note", content = "+@none" },
                ["3"] = { [""] = "+@text.note", content = "+@none" },
                ["4"] = { [""] = "+@text.note", content = "+@none" },
                ["5"] = { [""] = "+@text.note", content = "+@none" },
                ["6"] = { [""] = "+@text.note", content = "+@none" },
            },
            cancelled = {
                ["1"] = { [""] = "+Whitespace", content = "+@none" },
                ["2"] = { [""] = "+Whitespace", content = "+@none" },
                ["3"] = { [""] = "+Whitespace", content = "+@none" },
                ["4"] = { [""] = "+Whitespace", content = "+@none" },
                ["5"] = { [""] = "+Whitespace", content = "+@none" },
                ["6"] = { [""] = "+Whitespace", content = "+@none" },
            },
            urgent = {
                ["1"] = { [""] = "+@text.danger", content = "+@none" },
                ["2"] = { [""] = "+@text.danger", content = "+@none" },
                ["3"] = { [""] = "+@text.danger", content = "+@none" },
                ["4"] = { [""] = "+@text.danger", content = "+@none" },
                ["5"] = { [""] = "+@text.danger", content = "+@none" },
                ["6"] = { [""] = "+@text.danger", content = "+@none" },
            },
            uncertain = {
                ["1"] = { [""] = "+@boolean", content = "+@none" },
                ["2"] = { [""] = "+@boolean", content = "+@none" },
                ["3"] = { [""] = "+@boolean", content = "+@none" },
                ["4"] = { [""] = "+@boolean", content = "+@none" },
                ["5"] = { [""] = "+@boolean", content = "+@none" },
                ["6"] = { [""] = "+@boolean", content = "+@none" },
            },
            recurring = {
                ["1"] = { [""] = "+@repeat", content = "+@none" },
                ["2"] = { [""] = "+@repeat", content = "+@none" },
                ["3"] = { [""] = "+@repeat", content = "+@none" },
                ["4"] = { [""] = "+@repeat", content = "+@none" },
                ["5"] = { [""] = "+@repeat", content = "+@none" },
                ["6"] = { [""] = "+@repeat", content = "+@none" },
            },
        },

        lists = {
            unordered = {
                ["1"] = {
                    prefix = "+@punctuation.delimiter",
                    content = "+@none",
                },
                ["2"] = {
                    prefix = "+@punctuation.delimiter",
                    content = "+@none",
                },
                ["3"] = {
                    prefix = "+@punctuation.delimiter",
                    content = "+@none",
                },
                ["4"] = {
                    prefix = "+@punctuation.delimiter",
                    content = "+@none",
                },
                ["5"] = {
                    prefix = "+@punctuation.delimiter",
                    content = "+@none",
                },
                ["6"] = {
                    prefix = "+@punctuation.delimiter",
                    content = "+@none",
                },
            },

            ordered = {
                ["1"] = {
                    prefix = "+@repeat",
                    content = "+@none",
                },
                ["2"] = {
                    prefix = "+@repeat",
                    content = "+@none",
                },
                ["3"] = {
                    prefix = "+@repeat",
                    content = "+@none",
                },
                ["4"] = {
                    prefix = "+@repeat",
                    content = "+@none",
                },
                ["5"] = {
                    prefix = "+@repeat",
                    content = "+@none",
                },
                ["6"] = {
                    prefix = "+@repeat",
                    content = "+@none",
                },
            },
        },

        quotes = {
            ["1"] = {
                prefix = "+@punctuation.delimiter",
                content = "+@punctuation.delimiter",
            },
            ["2"] = {
                prefix = "+Blue",
                content = "+Blue",
            },
            ["3"] = {
                prefix = "+Yellow",
                content = "+Yellow",
            },
            ["4"] = {
                prefix = "+Red",
                content = "+Red",
            },
            ["5"] = {
                prefix = "+Green",
                content = "+Green",
            },
            ["6"] = {
                prefix = "+Brown",
                content = "+Brown",
            },
        },

        anchors = {
            declaration = {
                [""] = "+@text.reference",
                delimiter = "+NonText",
            },
            definition = {
                delimiter = "+NonText",
            },
        },

        insertions = {
            [""] = "cterm=bold gui=bold",
            prefix = "+@punctuation.delimiter",
            variable = {
                name = "+@string",
                value = "+@punctuation.delimiter",
            },
            item = "+@namespace",
            parameters = "+@comment",
        },

        links = {
            description = {
                [""] = "+@text.uri",
                delimiter = "+NonText",
            },

            file = {
                [""] = "+@comment",
                delimiter = "+NonText",
            },

            location = {
                delimiter = "+NonText",

                url = "+@text.uri",

                generic = {
                    [""] = "+@type",
                    prefix = "+@type",
                },

                external_file = {
                    [""] = "+@label",
                    prefix = "+@label",
                },

                marker = {
                    [""] = "+@neorg.markers.title",
                    prefix = "+@neorg.markers.prefix",
                },

                definition = {
                    [""] = "+@neorg.definitions.title",
                    prefix = "+@neorg.definitions.prefix",
                },

                footnote = {
                    [""] = "+@neorg.footnotes.title",
                    prefix = "+@neorg.footnotes.prefix",
                },

                heading = {
                    ["1"] = {
                        [""] = "+@neorg.headings.1.title",
                        prefix = "+@neorg.headings.1.prefix",
                    },

                    ["2"] = {
                        [""] = "+@neorg.headings.2.title",
                        prefix = "+@neorg.headings.2.prefix",
                    },

                    ["3"] = {
                        [""] = "+@neorg.headings.3.title",
                        prefix = "+@neorg.headings.3.prefix",
                    },

                    ["4"] = {
                        [""] = "+@neorg.headings.4.title",
                        prefix = "+@neorg.headings.4.prefix",
                    },

                    ["5"] = {
                        [""] = "+@neorg.headings.5.title",
                        prefix = "+@neorg.headings.5.prefix",
                    },

                    ["6"] = {
                        [""] = "+@neorg.headings.6.title",
                        prefix = "+@neorg.headings.6.prefix",
                    },
                },
            },
        },

        markup = {
            bold = {
                [""] = "+@text.strong",
                delimiter = "+NonText",
            },
            italic = {
                [""] = "+@text.emphasis",
                delimiter = "+NonText",
            },
            underline = {
                [""] = "cterm=underline gui=underline",
                delimiter = "+NonText",
            },
            strikethrough = {
                [""] = "cterm=strikethrough gui=strikethrough",
                delimiter = "+NonText",
            },
            spoiler = {
                [""] = "+@text.danger",
                delimiter = "+NonText",
            },
            subscript = {
                [""] = "+@label",
                delimiter = "+NonText",
            },
            superscript = {
                [""] = "+@number",
                delimiter = "+NonText",
            },
            variable = {
                [""] = "+@neorg.insertions.variable.name",
                delimiter = "+NonText",
            },
            verbatim = {
                delimiter = "+NonText",
            },
            inline_comment = {
                delimiter = "+NonText",
            },
            inline_math = {
                [""] = "+@text.math",
                delimiter = "+NonText",
            },
        },

        delimiters = {
            strong = "+@punctuation.delimiter",
            weak = "+@punctuation.delimiter",
            horizontal_line = "+@punctuation.delimiter",
        },

        modifiers = {
            trailing = "+NonText",
            link = "+NonText",
            escape = "+@type",
        },
    },

    -- Where and how to dim TS types
    dim = {
        tags = {
            ranged_verbatim = {
                code_block = {
                    reference = "Normal",
                    percentage = 15,
                    affect = "background",
                },
            },
        },

        markup = {
            verbatim = {
                reference = "Normal",
                percentage = 20,
            },

            inline_comment = {
                reference = "Normal",
                percentage = 40,
            },
        },
    },

    -- This can be one of four values: `false`, `"all"`, `"except_undone"` and `"cancelled"`.
    -- - When set to `false` the content of TODO items will not be coloured in any special way.
    -- - When set to `"all"` the content of TODO items will directly reflect the colour of the item's TODO box.
    -- - When set to `"except_undone"`, will have the same behaviour as `"all"` but will exclude undone TODO items.
    -- - When set to `"cancelled"` will only highlight the content of TODO items for cancelled tasks.
    --
    -- Default value: "cancelled".
    todo_items_match_color = "cancelled",
}

module.setup = function()
    return { success = true, requires = { "core.autocommands" } }
end

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("ColorScheme", true)

    if module.config.public.todo_items_match_color then
        if
            not vim.tbl_contains({ "all", "except_undone", "cancelled" }, module.config.public.todo_items_match_color)
        then
            log.error(
                "Error when parsing `todo_items_match_color` for `core.highlights`, the key only accepts the following values: all, except_undone and cancelled."
            )
            return
        end

        for i = 1, 6 do
            local todo_items = module.config.public.highlights.todo_items
            local index = tostring(i)

            if module.config.public.todo_items_match_color ~= "cancelled" then
                if module.config.public.todo_items_match_color ~= "except_undone" then
                    todo_items.undone[index].content = todo_items.undone[index][""]
                end

                todo_items.pending[index].content = todo_items.pending[index][""]
                todo_items.done[index].content = todo_items.done[index][""]
                todo_items.urgent[index].content = todo_items.urgent[index][""]
                todo_items.on_hold[index].content = todo_items.on_hold[index][""]
                todo_items.recurring[index].content = todo_items.recurring[index][""]
                todo_items.uncertain[index].content = todo_items.uncertain[index][""]
            end

            todo_items.cancelled[index].content = todo_items.cancelled[index][""]
        end
    end

    module.public.trigger_highlights()

    vim.api.nvim_create_autocmd("ColorScheme", {
        callback = module.public.trigger_highlights,
    })
end

---@class core.highlights
module.public = {

    --- Reads the highlights configuration table and applies all defined highlights
    trigger_highlights = function()
        --- Recursively descends down the highlight configuration and applies every highlight accordingly
        ---@param highlights table #The table of highlights to descend down
        ---@param callback #(function(hl_name, highlight, prefix) -> bool) - a callback function to be invoked for every highlight. If it returns true then we should recurse down the table tree further
        ---@param prefix string #Should be only used by the function itself, acts as a "savestate" so the function can keep track of what path it has descended down
        local function descend(highlights, callback, prefix)
            -- Loop through every highlight defined in the provided table
            for hl_name, highlight in pairs(highlights) do
                -- If the callback returns true then descend further down the table tree
                if callback(hl_name, highlight, prefix) then
                    descend(highlight, callback, prefix .. "." .. hl_name)
                end
            end
        end

        -- Begin the descent down the public highlights configuration table
        descend(module.config.public.highlights, function(hl_name, highlight, prefix)
            -- If the type of highlight we have encountered is a table
            -- then recursively descend down it as well
            if type(highlight) == "table" then
                return true
            end

            -- Trim any potential leading and trailing whitespace
            highlight = vim.trim(highlight)

            -- Check whether we are trying to link to an existing hl group
            -- by checking for the existence of the + sign at the front
            local is_link = highlight:sub(1, 1) == "+"

            local full_highlight_name = "@neorg" .. prefix .. (hl_name:len() > 0 and ("." .. hl_name) or "")
            local does_hl_exist = neorg.lib.inline_pcall(vim.api.nvim_exec, "highlight " .. full_highlight_name, true)

            -- If we are dealing with a link then link the highlights together (excluding the + symbol)
            if is_link then
                -- If the highlight already exists then assume the user doesn't want it to be
                -- overwritten
                if does_hl_exist and does_hl_exist:len() > 0 and not does_hl_exist:match("xxx%s+cleared") then
                    return
                end

                vim.api.nvim_set_hl(0, full_highlight_name, {
                    link = highlight:sub(2),
                })
            else -- Otherwise simply apply the highlight options the user provided
                -- If the highlight already exists then assume the user doesn't want it to be
                -- overwritten
                if does_hl_exist and does_hl_exist:len() > 0 then
                    return
                end

                -- We have to use vim.cmd here
                vim.cmd({
                    cmd = "highlight",
                    args = { full_highlight_name, highlight },
                    bang = true,
                })
            end
        end, "")

        -- Begin the descent down the dimming configuration table
        descend(module.config.public.dim, function(hl_name, highlight, prefix)
            -- If we don't have a percentage value then keep traversing down the table tree
            if not highlight.percentage then
                return true
            end

            local full_highlight_name = "@neorg" .. prefix .. (hl_name:len() > 0 and ("." .. hl_name) or "")
            local does_hl_exist = neorg.lib.inline_pcall(vim.api.nvim_exec, "highlight " .. full_highlight_name, true)

            -- If the highlight already exists then assume the user doesn't want it to be
            -- overwritten
            if does_hl_exist and does_hl_exist:len() > 0 and not does_hl_exist:match("xxx%s+cleared") then
                return
            end

            -- Apply the dimmed highlight
            vim.api.nvim_set_hl(0, full_highlight_name, {
                [highlight.affect == "background" and "bg" or "fg"] = module.public.dim_color(
                    module.public.get_attribute(
                        highlight.reference or full_highlight_name,
                        highlight.affect or "foreground"
                    ),
                    highlight.percentage
                ),
            })
        end, "")
    end,

    --- Takes in a table of highlights and applies them to the current buffer
    ---@param highlights table #A table of highlights
    add_highlights = function(highlights)
        module.config.public.highlights =
            vim.tbl_deep_extend("force", module.config.public.highlights, highlights or {})
        module.public.trigger_highlights()
    end,

    --- Takes in a table of items to dim and applies the dimming to them
    ---@param dim table #A table of items to dim
    add_dim = function(dim)
        module.config.public.dim = vim.tbl_deep_extend("force", module.config.public.dim, dim or {})
        module.public.trigger_highlights()
    end,

    --- Assigns all Neorg* highlights to `clear`
    clear_highlights = function()
        --- Recursively descends down the highlight configuration and clears every highlight accordingly
        ---@param highlights table #The table of highlights to descend down
        ---@param prefix string #Should be only used by the function itself, acts as a "savestate" so the function can keep track of what path it has descended down
        local function descend(highlights, prefix)
            -- Loop through every defined highlight
            for hl_name, highlight in pairs(highlights) do
                -- If it is a table then recursively traverse down it!
                if type(highlight) == "table" then
                    descend(highlight, hl_name)
                else -- Otherwise we're dealing with a string
                    -- Hence we should clear the highlight
                    vim.cmd("highlight! clear Neorg" .. prefix .. hl_name)
                end
            end
        end

        -- Begin the descent
        descend(module.config.public.highlights, "")
    end,

    -- NOTE: Shamelessly taken and tweaked a little from akinsho's nvim-bufferline:
    -- https://github.com/akinsho/nvim-bufferline.lua/blob/fec44821eededceadb9cc25bc610e5114510a364/lua/bufferline/colors.lua
    -- <3
    get_attribute = function(name, attribute)
        -- Attempt to get the highlight
        local success, hl = pcall(vim.api.nvim_get_hl_by_name, name, true)

        -- If we were successful and if the attribute exists then return it
        if success and hl[attribute] then
            return bit.tohex(hl[attribute], 6)
        else -- Else log the message in a regular info() call, it's not an insanely important error
            log.info("Unable to grab highlight for attribute", attribute, " - full error:", hl)
        end

        return "NONE"
    end,

    dim_color = function(colour, percent)
        if colour == "NONE" then
            return colour
        end

        local function hex_to_rgb(hex_colour)
            return tonumber(hex_colour:sub(1, 2), 16),
                tonumber(hex_colour:sub(3, 4), 16),
                tonumber(hex_colour:sub(5), 16)
        end

        local function alter(attr)
            return math.floor(attr * (100 - percent) / 100)
        end

        local r, g, b = hex_to_rgb(colour)

        if not r or not g or not b then
            return "NONE"
        end

        return string.format("#%02x%02x%02x", math.min(alter(r), 255), math.min(alter(g), 255), math.min(alter(b), 255))
    end,

    -- END of shamelessly ripped off akinsho code
}

module.events.subscribed = {
    ["core.autocommands"] = {
        colorscheme = true,
        bufenter = true,
    },
}

return module
