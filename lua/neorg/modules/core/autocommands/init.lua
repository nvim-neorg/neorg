--[[
    File: Autocommands
    Summary: Handles the creation and management of Neovim's autocommands.
    ---
This module exposes functionality for subscribing to autocommands and performing actions based on those autocommands.

In your `module.setup()`, make sure to require `core.autocommands` (`requires = { "core.autocommands" }`)
Afterwards in a function of your choice that gets called *after* core.autocommmands gets intialized (e.g. `load()`):

```lua
module.load = function()
    module.required["core.autocommands"].enable_autocommand("VimLeavePre") -- Substitute VimLeavePre for any valid neovim autocommand
end
```

Afterwards, be sure to subscribe to the event:

```lua
module.events.subscribed = {
    ["core.autocommands"] = {
        vimleavepre = true
    }
}
```

Upon receiving an event, it will come in this format:
```lua
{
    type = "<name of autocommand, e.g. vimleavepre>",
    broadcast = true
}
```
--]]

local neorg = require("neorg.core")
local modules = require("neorg.modules")
local module = modules.create("core.autocommands")

--- This function gets invoked whenever a core.autocommands enabled autocommand is triggered. Note that this function should be only used internally
---@param name string #The name of the autocommand that was just triggered
---@param triggered_from_norg boolean #If true, that means we have received this event as part of a *.norg autocommand
function _neorg_module_autocommand_triggered(name, triggered_from_norg)
    neorg.events.new(
        module,
        name,
        { norg = triggered_from_norg }
    ):broadcast(modules.loaded_modules)
end

---@class core.autocommands
module.public = {

    --- By default, all autocommands are disabled for performance reasons. To enable them, use this command. If an invalid autocmd is given nothing happens.
    ---@param autocmd string #The relative name of the autocommand to enable
    ---@param dont_isolate boolean #Defaults to false. Specifies whether the autocommand should run globally (* instead of in Neorg files (*.norg)
    enable_autocommand = function(autocmd, dont_isolate)
        dont_isolate = dont_isolate or false

        autocmd = autocmd:lower()
        local subscribed_autocommand = module.events.subscribed["core.autocommands"][autocmd]

        if subscribed_autocommand ~= nil then
            vim.cmd("augroup Neorg")

            if dont_isolate and vim.fn.exists("#Neorg#" .. autocmd .. "#*") == 0 then
                vim.cmd(
                    "autocmd "
                        .. autocmd
                        .. ' * :lua _neorg_module_autocommand_triggered("'
                        .. autocmd
                        .. '", false)'
                )
            elseif vim.fn.exists("#Neorg#" .. autocmd .. "#*.norg") == 0 then
                vim.cmd(
                    "autocmd "
                        .. autocmd
                        .. ' *.norg :lua _neorg_module_autocommand_triggered("'
                        .. autocmd
                        .. '", true)'
                )
            end
            vim.cmd("augroup END")
            module.events.subscribed["core.autocommands"][autocmd] = true
        end
    end,

    version = "0.0.8",
}

-- All the subscribeable events for core.autocommands
module.events.subscribed = {

    ["core.autocommands"] = {

        bufadd = false,
        bufdelete = false,
        bufenter = false,
        buffilepost = false,
        buffilepre = false,
        bufhidden = false,
        bufleave = false,
        bufmodifiedset = false,
        bufnew = false,
        bufnewfile = false,
        bufread = false,
        bufreadcmd = false,
        bufreadpre = false,
        bufunload = false,
        bufwinenter = false,
        bufwinleave = false,
        bufwipeout = false,
        bufwrite = false,
        bufwritecmd = false,
        bufwritepost = false,
        chaninfo = false,
        chanopen = false,
        cmdundefined = false,
        cmdlinechanged = false,
        cmdlineenter = false,
        cmdlineleave = false,
        cmdwinenter = false,
        cmdwinleave = false,
        colorscheme = false,
        colorschemepre = false,
        completechanged = false,
        completedonepre = false,
        completedone = false,
        cursorhold = false,
        cursorholdi = false,
        cursormoved = false,
        cursormovedi = false,
        diffupdated = false,
        dirchanged = false,
        fileappendcmd = false,
        fileappendpost = false,
        fileappendpre = false,
        filechangedro = false,
        exitpre = false,
        filechangedshell = false,
        filechangedshellpost = false,
        filereadcmd = false,
        filereadpost = false,
        filereadpre = false,
        filetype = false,
        filewritecmd = false,
        filewritepost = false,
        filewritepre = false,
        filterreadpost = false,
        filterreadpre = false,
        filterwritepost = false,
        filterwritepre = false,
        focusgained = false,
        focuslost = false,
        funcundefined = false,
        uienter = false,
        uileave = false,
        insertchange = false,
        insertcharpre = false,
        textyankpost = false,
        insertenter = false,
        insertleavepre = false,
        insertleave = false,
        menupopup = false,
        optionset = false,
        quickfixcmdpre = false,
        quickfixcmdpost = false,
        quitpre = false,
        remotereply = false,
        sessionloadpost = false,
        shellcmdpost = false,
        signal = false,
        shellfilterpost = false,
        sourcepre = false,
        sourcepost = false,
        sourcecmd = false,
        spellfilemissing = false,
        stdinreadpost = false,
        stdinreadpre = false,
        swapexists = false,
        syntax = false,
        tabenter = false,
        tableave = false,
        tabnew = false,
        tabnewentered = false,
        tabclosed = false,
        termopen = false,
        termenter = false,
        termleave = false,
        termclose = false,
        termresponse = false,
        textchanged = false,
        textchangedi = false,
        textchangedp = false,
        user = false,
        usergettingbored = false,
        vimenter = false,
        vimleave = false,
        vimleavepre = false,
        vimresized = false,
        vimresume = false,
        vimsuspend = false,
        winclosed = false,
        winenter = false,
        winleave = false,
        winnew = false,
        winscrolled = false,
    },
}

-- All the autocommand definitions
module.events.defined = {
    bufadd = "bufadd",
    bufdelete = "bufdelete",
    bufenter = "bufenter",
    buffilepost = "buffilepost",
    buffilepre = "buffilepre",
    bufhidden = "bufhidden",
    bufleave = "bufleave",
    bufmodifiedset = "bufmodifiedset",
    bufnew = "bufnew",
    bufnewfile = "bufnewfile",
    bufread = "bufread",
    bufreadcmd = "bufreadcmd",
    bufreadpre = "bufreadpre",
    bufunload = "bufunload",
    bufwinenter = "bufwinenter",
    bufwinleave = "bufwinleave",
    bufwipeout = "bufwipeout",
    bufwrite = "bufwrite",
    bufwritecmd = "bufwritecmd",
    bufwritepost = "bufwritepost",
    chaninfo = "chaninfo",
    chanopen = "chanopen",
    cmdundefined = "cmdundefined",
    cmdlinechanged = "cmdlinechanged",
    cmdlineenter = "cmdlineenter",
    cmdlineleave = "cmdlineleave",
    cmdwinenter = "cmdwinenter",
    cmdwinleave = "cmdwinleave",
    colorscheme = "colorscheme",
    colorschemepre = "colorschemepre",
    completechanged = "completechanged",
    completedonepre = "completedonepre",
    completedone = "completedone",
    cursorhold = "cursorhold",
    cursorholdi = "cursorholdi",
    cursormoved = "cursormoved",
    cursormovedi = "cursormovedi",
    diffupdated = "diffupdated",
    dirchanged = "dirchanged",
    fileappendcmd = "fileappendcmd",
    fileappendpost = "fileappendpost",
    fileappendpre = "fileappendpre",
    filechangedro = "filechangedro",
    exitpre = "exitpre",
    filechangedshell = "filechangedshell",
    filechangedshellpost = "filechangedshellpost",
    filereadcmd = "filereadcmd",
    filereadpost = "filereadpost",
    filereadpre = "filereadpre",
    filetype = "filetype",
    filewritecmd = "filewritecmd",
    filewritepost = "filewritepost",
    filewritepre = "filewritepre",
    filterreadpost = "filterreadpost",
    filterreadpre = "filterreadpre",
    filterwritepost = "filterwritepost",
    filterwritepre = "filterwritepre",
    focusgained = "focusgained",
    focuslost = "focuslost",
    funcundefined = "funcundefined",
    uienter = "uienter",
    uileave = "uileave",
    insertchange = "insertchange",
    insertcharpre = "insertcharpre",
    textyankpost = "textyankpost",
    insertenter = "insertenter",
    insertleavepre = "insertleavepre",
    insertleave = "insertleave",
    menupopup = "menupopup",
    optionset = "optionset",
    quickfixcmdpre = "quickfixcmdpre",
    quickfixcmdpost = "quickfixcmdpost",
    quitpre = "quitpre",
    remotereply = "remotereply",
    sessionloadpost = "sessionloadpost",
    shellcmdpost = "shellcmdpost",
    signal = "signal",
    shellfilterpost = "shellfilterpost",
    sourcepre = "sourcepre",
    sourcepost = "sourcepost",
    sourcecmd = "sourcecmd",
    spellfilemissing = "spellfilemissing",
    stdinreadpost = "stdinreadpost",
    stdinreadpre = "stdinreadpre",
    swapexists = "swapexists",
    syntax = "syntax",
    tabenter = "tabenter",
    tableave = "tableave",
    tabnew = "tabnew",
    tabnewentered = "tabnewentered",
    tabclosed = "tabclosed",
    termopen = "termopen",
    termenter = "termenter",
    termleave = "termleave",
    termclose = "termclose",
    termresponse = "termresponse",
    textchanged = "textchanged",
    textchangedi = "textchangedi",
    textchangedp = "textchangedp",
    user = "user",
    usergettingbored = "usergettingbored",
    vimenter = "vimenter",
    vimleave = "vimleave",
    vimleavepre = "vimleavepre",
    vimresized = "vimresized",
    vimresume = "vimresume",
    vimsuspend = "vimsuspend",
    winclosed = "winclosed",
    winenter = "winenter",
    winleave = "winleave",
    winnew = "winnew",
    winscrolled = "winscrolled",
}

module.examples = {
    ["Binding to an Autocommand"] = function()
        local mymodule = modules.create("my.module")

        mymodule.setup = function()
            return {
                success = true,
                requires = {
                    "core.autocommands", -- Be sure to require the module!
                },
            }
        end

        mymodule.load = function()
            -- Enable an autocommand (in this case InsertLeave)
            module.required["core.autocommands"].enable_autocommand("InsertLeave")
        end

        -- Listen for any incoming events
        mymodule.on_event = function(event)
            -- If it's the event we're looking for then do something!
            if event.name == "insertleave" then
                neorg.log.warn("We left insert mode!")
            end
        end

        mymodule.events.subscribed = {
            ["core.autocommands"] = {
                insertleave = true, -- Be sure to listen in for this event!
            },
        }

        return mymodule
    end,
}

return module
