require("neorg.modules.base")

local module = neorg.modules.create("core.cheatsheet")
local log = require("neorg.external.log")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.neorgcmd",
            "core.ui",
        },
    }
end

module.private = {
    ns = nil,
    win = nil,
    buf = nil,
    lines = {
        [[@document.meta]],
        [[title: Neorg cheatsheet]],
        [[description: The Neorg cheatsheet]],
        [[author: The Neorg Community]],
        [[categories: docs]],
        [[created: 2021-09-05]],
        [[version: 0.1]],
        [[@end]],
        [[]],
        [[* Basic Info]],
        [[  You can always nest up to 6 levels.]],
        [[]],
        [[* Markup]],
        [[  - \*bold\*: *bold*]],
        [[  - \/italic\/: /italic/]],
        [[  - \_underline\_: _underline_]],
        [[  - \-strikethrough\-: -strikethrough-]],
        [[  - \|spoiler\|: |spoiler|]],
        [[  - \`inline code\`: `inline code`]],
        [[  - \^superscript\^: ^superscript^  (when nested into `subscript`, will highlight as an error)]],
        [[  - \,subscript\,: ,subscript,  (when nested into `superscript`, will highlight as an error)]],
        [[  - \$inline math\$: $f(x) = y$ (see also {# Math})]],
        [[  - \=variable\=: =variable= (see also {# Variables})]],
        [[  - \+inline comment\+: +inline comment+]],
        [[]],
        [[* Lists]],
        [[  @code norg]],
        [[  - Unordered List item]],
        [[  ~~ Nested Ordered List Item]],
        [[  @end]],
        [[]],
        [[** Task Lists]],
        [[   @code norg]],
        [[   - [ ] Undone -> not done yet]],
        [[   - [x] Done -> done with that]],
        [[   - [?] Needs further input]],
        [[]],
        [[   - [!] Urgent -> high priority task]],
        [[   - [+] Recurring task with children]],
        [[]],
        [[   - [-] Pending -> currently in progress]],
        [[   - [=] Task put on hold]],
        [[   - [_] Task cancelled (put down)]],
        [[   @end]],
        [[]],
        [[* Quotes]],
        [[  @code norg]],
        [[  > Quote]],
        [[  >> Nested quote]],
        [[  @end]],
        [[]],
        [[* Headings]],
        [[  @code norg]],
        [[  **** 4. level heading]],
        [[  ***** 5. level heading]],
        [[        ---]],
        [[       back to level 4]],
        [[       ===]],
        [[  back to root level]],
        [[  @end]],
        [[]],
        [[* Links]],
        [[  @code norg]],
        [[  {* Heading 1}]],
        [[  {** Heading 2}]],
        [[  {*** Heading 3}]],
        [[  {**** Heading 4}]],
        [[  {***** Heading 5}]],
        [[  {****** Heading 6}]],
        [[  {******* Heading level above 6}]],
        [[  {# Generic}]],
        [[  {| Marker}]],
        [[  {$ Definition}]],
        [[  {^ Footnote}]],
        [[  {:norg_file:}]],
        [[  {:norg_file:* Heading 1}]],
        [[  {:norg_file:** Heading 2}]],
        [[  {:norg_file:*** Heading 3}]],
        [[  {:norg_file:**** Heading 4}]],
        [[  {:norg_file:***** Heading 5}]],
        [[  {:norg_file:****** Heading 6}]],
        [[  {:norg_file:******* Heading level above 6}]],
        [[  {:norg_file:# Generic}]],
        [[  {:norg_file:| Marker}]],
        [[  {:norg_file:$ Definition}]],
        [[  {:norg_file:^ Footnote}]],
        [[  {https://github.com/}]],
        [[  {file:///dev/null}]],
        [[  {@ external_file.txt}]],
        [[  Note, that the following links are malformed:]],
        [[  {:norg_file:@ external_file.txt}]],
        [[  {:norg_file:https://github.com/}]],
        [[  @end]],
    },
    heading_lines = {},
    displayed = false,
    show_cheatsheet = function()
        if module.private.displayed then
            return
        end
        local width = vim.o.columns
        local height = vim.o.lines
        module.private.buf = module.required["core.ui"].create_norg_buffer("cheatsheet", "nosplit")
        vim.api.nvim_buf_set_option(module.private.buf, "bufhidden", "wipe")
        vim.api.nvim_buf_set_lines(module.private.buf, 0, -1, false, module.private.lines)
        vim.api.nvim_buf_set_option(module.private.buf, "modifiable", false)
        local nore_silent = { noremap = true, silent = true, nowait = true }
        if type(module.config.public.keybinds.close) == "table" then
            for _, keybind in ipairs(module.config.public.keybinds.close) do
                vim.api.nvim_buf_set_keymap(module.private.buf, "n", keybind, "<cmd>q<CR>", nore_silent)
            end
        elseif type(module.config.public.keybinds.close) == "string" then
            vim.api.nvim_buf_set_keymap(
                module.private.buf,
                "n",
                module.config.public.keybinds.close,
                "<cmd>q<CR>",
                nore_silent
            )
        else
            log.warn("[cheatsheet]: Invalid option for module.config.public.keybinds.close")
            vim.api.nvim_buf_set_keymap(module.private.buf, "n", "q", "<cmd>q<CR>", nore_silent)
        end
        vim.api.nvim_buf_set_keymap(
            module.private.buf,
            "n",
            "<cr>",
            "<cmd>Neorg keybind norg core.norg.esupports.hop.hop-link<CR>",
            nore_silent
        )
        vim.api.nvim_buf_set_option(module.private.buf, "filetype", "norg")
        module.private.win = vim.api.nvim_open_win(module.private.buf, true, {
            relative = "editor",
            width = math.floor(width * 0.6),
            height = math.floor(height * 0.9),
            col = math.floor(width * 0.2),
            row = math.floor(height * 0.1),
            border = "single",
            style = "minimal",
        })
        for i = 0, #module.private.lines do
            vim.api.nvim_buf_add_highlight(module.private.buf, module.private.ns, "NormalFloat", i, 0, -1)
        end
        module.private.displayed = true
    end,
    close_cheatsheet = function()
        if not module.private.displayed then
            return
        end
        vim.api.nvim_win_close(module.private.win, true)
        module.private.displayed = false
    end,
    toggle_cheatsheet = function()
        if module.private.displayed then
            module.private.close_cheatsheet()
        else
            module.private.show_cheatsheet()
        end
    end,
}

module.config.public = {
    keybinds = {
        close = { "q", "<esc>" },
    },
}

module.public = {
    version = "0.0.1",
}

module.load = function()
    vim.cmd([[highlight default NeorgCheatSectionContent guibg = #353b45]])
    vim.cmd([[highlight default NeorgCheatHeading guifg = #8bcd5b]])
    vim.cmd([[highlight default NeorgCheatBorder guifg = #617190 guibg = #353b45]])
    local section_title_colors = {
        "#41a7fc",
        "#ea8912",
        "#f65866",
        "#ebc275",
        "#c678dd",
        "#34bfd0",
    }
    for i, color in ipairs(section_title_colors) do
        vim.cmd("highlight default NeorgCheatTopic" .. i .. " guifg = " .. color)
    end
    module.private.ns = vim.api.nvim_create_namespace("neorg_cheatsheet")
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            cheatsheet = {
                open = {},
                close = {},
                toggle = {},
            },
        },
        data = {
            cheatsheet = {
                min_args = 1,
                max_args = 1,
                subcommands = {
                    open = { args = 0, name = "cheatsheet.open" },
                    close = { args = 0, name = "cheatsheet.close" },
                    toggle = { args = 0, name = "cheatsheet.toggle" },
                },
            },
        },
    })
end

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        if event.split_type[2] == "cheatsheet.open" then
            module.private.show_cheatsheet()
        elseif event.split_type[2] == "cheatsheet.close" then
            module.private.close_cheatsheet()
        elseif event.split_type[2] == "cheatsheet.toggle" then
            module.private.toggle_cheatsheet()
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["cheatsheet.open"] = true,
        ["cheatsheet.close"] = true,
        ["cheatsheet.toggle"] = true,
    },
}

return module
