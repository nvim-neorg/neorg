--[[
	Neorg module for managing highlight groups.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.highlights")

--[[
    Nested trees concatenate
    So:
   	   tag = { begin = "+Comment" }
	matches the highlight group:
		NeorgTagBegin
	and converts into the command:
		highlight! link NeorgTagBegin Comment
--]]
module.config.public = {
    highlights = {
        ConcealURL = {
            [""] = "+TSURI",
            Value = "+TSType",
        },
        Conceal = {
            Bold = "cterm=bold gui=bold",
            Italic = "cterm=italic gui=italic",
            Underline = "cterm=underline gui=underline",
            Strikethrough = "cterm=strikethrough gui=strikethrough",
        },

        SelectionWindow = {
            Heading = "+TSAnnotation",
            Arrow = "+Normal",
            Key = "+TSNamespace",
            Keyname = "+TSMath",
            Nestedkeyname = "+TSString",
        },
    },
    dim = {
        Conceal = {
            Monospace = {
                reference = "Normal",
                percentage = 20,
            },
            Comment = {
                reference = "Normal",
                percentage = 40,
            },
        },
    },
}

module.setup = function()
    return { success = true, requires = { "core.autocommands" } }
end

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("ColorScheme", true)
end

module.public = {

    -- @Summary	Defines all the highlight groups for Neorg
    -- @Description Reads the highlights configuration table and applies all defined highlights
    trigger_highlights = function()
        local descend

        -- @Summary Descends down a tree of highlights and applies them
        -- @Description Recursively descends down the highlight configuration and applies every highlight accordingly
        -- @Param  highlights (table) - the table of highlights to descend down
        -- @Param  callback (function(hl_name, highlight, prefix) -> bool) - a callback function to be invoked for every highlight. If it returns true then we should recurse down the table tree further
        -- @Param  prefix (string) - should be only used by the function itself, acts as a "savestate" so the function can keep track of what path it has descended down
        descend = function(highlights, callback, prefix)
            -- Loop through every highlight defined in the provided table
            for hl_name, highlight in pairs(highlights) do
                -- If the callback returns true then descend further down the table tree
                if callback(hl_name, highlight, prefix) then
                    descend(highlight, callback, prefix .. hl_name)
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

            -- If we are dealing with a link then link the highlights together (excluding the + symbol)
            if is_link then
                local full_highlight_name = "Neorg" .. prefix .. hl_name

                -- If the highlight already exists then assume the user doesn't want it to be
                -- overwritten
                -- TODO: Reinstantiate ASAP. Currently it causes problems with highlights not applying.
                -- if vim.fn.hlexists(full_highlight_name) == 1 then
                --     return
                -- end

                vim.cmd("highlight! link " .. full_highlight_name .. " " .. highlight:sub(2))
            else -- Otherwise simply apply the highlight options the user provided
                local full_highlight_name = "Neorg" .. prefix .. hl_name

                -- If the highlight already exists then assume the user doesn't want it to be
                -- overwritten
                if vim.fn.hlexists(full_highlight_name) == 1 then
                    return
                end

                vim.cmd("highlight! " .. full_highlight_name .. " " .. highlight)
            end
        end, "")

        -- Begin the descent down the dimming configuration table
        descend(module.config.public.dim, function(hl_name, highlight, prefix)
            -- If we don't have a percentage value then keep traversing down the table tree
            if not highlight.percentage then
                return true
            end

            -- Apply the dimmed highlight
            vim.cmd(
                "highlight! Neorg"
                    .. prefix
                    .. hl_name
                    .. " "
                    .. (highlight.affect == "background" and "guibg" or "guifg")
                    .. "="
                    .. module.public.dim_color(
                        module.public.get_attribute(
                            highlight.reference or ("Neorg" .. prefix .. hl_name),
                            highlight.affect or "foreground"
                        ),
                        highlight.percentage
                    )
            )
        end, "")
    end,

    -- @Summary Adds a set of highlights from a table
    -- @Description Takes in a table of highlights and applies them to the current buffer
    -- @Param  highlights (table) - a table of highlights
    add_highlights = function(highlights)
        module.config.public.highlights = vim.tbl_deep_extend(
            "force",
            module.config.public.highlights,
            highlights or {}
        )
        module.public.trigger_highlights()
    end,

    -- @Summary Adds a set of dims from a table
    -- @Description Takes in a table of items to dim and applies the dimming to them
    -- @Param  dim (table) - a table of items to dim
    add_dim = function(dim)
        module.config.public.dim = vim.tbl_deep_extend("force", module.config.public.dim, dim or {})
        module.public.trigger_highlights()
    end,

    -- @Summary Clears all the highlights defined by Neorg
    -- @Description Assigns all Neorg* highlights to `clear`
    clear_highlights = function()
        local descend

        -- @Summary Descends down a tree of highlights and clears them
        -- @Description Recursively descends down the highlight configuration and clears every highlight accordingly
        -- @Param  highlights (table) - the table of highlights to descend down
        -- @Param  prefix (string) - should be only used by the function itself, acts as a "savestate" so the function can keep track of what path it has descended down
        descend = function(highlights, prefix)
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

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" or event.type == "core.autocommands.events.colorscheme" then
        module.public.trigger_highlights()
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        colorscheme = true,
        bufenter = true,
    },
}

return module
