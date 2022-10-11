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
    type = "core.autocommands.events.<name of autocommand, e.g. vimleavepre>",
    broadcast = true
}
```
--]]

require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.autocommands")

--- This function gets invoked whenever a core.autocommands enabled autocommand is triggered. Note that this function should be only used internally
---@param name string #The name of the autocommand that was just triggered
---@param triggered_from_norg boolean #If true, that means we have received this event as part of a *.norg autocommand
function _neorg_module_autocommand_triggered(name, triggered_from_norg)
    neorg.events.broadcast_event(neorg.events.create(module, name, { norg = triggered_from_norg }))
end

-- A convenience wrapper around neorg.events.define_event
module.autocmd_base = function(name)
    return neorg.events.define(module, name)
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
                        .. ' * :lua _neorg_module_autocommand_triggered("core.autocommands.events.'
                        .. autocmd
                        .. '", false)'
                )
            elseif vim.fn.exists("#Neorg#" .. autocmd .. "#*.norg") == 0 then
                vim.cmd(
                    "autocmd "
                        .. autocmd
                        .. ' *.norg :lua _neorg_module_autocommand_triggered("core.autocommands.events.'
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

    bufadd = module.autocmd_base("bufadd"),
    bufdelete = module.autocmd_base("bufdelete"),
    bufenter = module.autocmd_base("bufenter"),
    buffilepost = module.autocmd_base("buffilepost"),
    buffilepre = module.autocmd_base("buffilepre"),
    bufhidden = module.autocmd_base("bufhidden"),
    bufleave = module.autocmd_base("bufleave"),
    bufmodifiedset = module.autocmd_base("bufmodifiedset"),
    bufnew = module.autocmd_base("bufnew"),
    bufnewfile = module.autocmd_base("bufnewfile"),
    bufread = module.autocmd_base("bufread"),
    bufreadcmd = module.autocmd_base("bufreadcmd"),
    bufreadpre = module.autocmd_base("bufreadpre"),
    bufunload = module.autocmd_base("bufunload"),
    bufwinenter = module.autocmd_base("bufwinenter"),
    bufwinleave = module.autocmd_base("bufwinleave"),
    bufwipeout = module.autocmd_base("bufwipeout"),
    bufwrite = module.autocmd_base("bufwrite"),
    bufwritecmd = module.autocmd_base("bufwritecmd"),
    bufwritepost = module.autocmd_base("bufwritepost"),
    chaninfo = module.autocmd_base("chaninfo"),
    chanopen = module.autocmd_base("chanopen"),
    cmdundefined = module.autocmd_base("cmdundefined"),
    cmdlinechanged = module.autocmd_base("cmdlinechanged"),
    cmdlineenter = module.autocmd_base("cmdlineenter"),
    cmdlineleave = module.autocmd_base("cmdlineleave"),
    cmdwinenter = module.autocmd_base("cmdwinenter"),
    cmdwinleave = module.autocmd_base("cmdwinleave"),
    colorscheme = module.autocmd_base("colorscheme"),
    colorschemepre = module.autocmd_base("colorschemepre"),
    completechanged = module.autocmd_base("completechanged"),
    completedonepre = module.autocmd_base("completedonepre"),
    completedone = module.autocmd_base("completedone"),
    cursorhold = module.autocmd_base("cursorhold"),
    cursorholdi = module.autocmd_base("cursorholdi"),
    cursormoved = module.autocmd_base("cursormoved"),
    cursormovedi = module.autocmd_base("cursormovedi"),
    diffupdated = module.autocmd_base("diffupdated"),
    dirchanged = module.autocmd_base("dirchanged"),
    fileappendcmd = module.autocmd_base("fileappendcmd"),
    fileappendpost = module.autocmd_base("fileappendpost"),
    fileappendpre = module.autocmd_base("fileappendpre"),
    filechangedro = module.autocmd_base("filechangedro"),
    exitpre = module.autocmd_base("exitpre"),
    filechangedshell = module.autocmd_base("filechangedshell"),
    filechangedshellpost = module.autocmd_base("filechangedshellpost"),
    filereadcmd = module.autocmd_base("filereadcmd"),
    filereadpost = module.autocmd_base("filereadpost"),
    filereadpre = module.autocmd_base("filereadpre"),
    filetype = module.autocmd_base("filetype"),
    filewritecmd = module.autocmd_base("filewritecmd"),
    filewritepost = module.autocmd_base("filewritepost"),
    filewritepre = module.autocmd_base("filewritepre"),
    filterreadpost = module.autocmd_base("filterreadpost"),
    filterreadpre = module.autocmd_base("filterreadpre"),
    filterwritepost = module.autocmd_base("filterwritepost"),
    filterwritepre = module.autocmd_base("filterwritepre"),
    focusgained = module.autocmd_base("focusgained"),
    focuslost = module.autocmd_base("focuslost"),
    funcundefined = module.autocmd_base("funcundefined"),
    uienter = module.autocmd_base("uienter"),
    uileave = module.autocmd_base("uileave"),
    insertchange = module.autocmd_base("insertchange"),
    insertcharpre = module.autocmd_base("insertcharpre"),
    textyankpost = module.autocmd_base("textyankpost"),
    insertenter = module.autocmd_base("insertenter"),
    insertleavepre = module.autocmd_base("insertleavepre"),
    insertleave = module.autocmd_base("insertleave"),
    menupopup = module.autocmd_base("menupopup"),
    optionset = module.autocmd_base("optionset"),
    quickfixcmdpre = module.autocmd_base("quickfixcmdpre"),
    quickfixcmdpost = module.autocmd_base("quickfixcmdpost"),
    quitpre = module.autocmd_base("quitpre"),
    remotereply = module.autocmd_base("remotereply"),
    sessionloadpost = module.autocmd_base("sessionloadpost"),
    shellcmdpost = module.autocmd_base("shellcmdpost"),
    signal = module.autocmd_base("signal"),
    shellfilterpost = module.autocmd_base("shellfilterpost"),
    sourcepre = module.autocmd_base("sourcepre"),
    sourcepost = module.autocmd_base("sourcepost"),
    sourcecmd = module.autocmd_base("sourcecmd"),
    spellfilemissing = module.autocmd_base("spellfilemissing"),
    stdinreadpost = module.autocmd_base("stdinreadpost"),
    stdinreadpre = module.autocmd_base("stdinreadpre"),
    swapexists = module.autocmd_base("swapexists"),
    syntax = module.autocmd_base("syntax"),
    tabenter = module.autocmd_base("tabenter"),
    tableave = module.autocmd_base("tableave"),
    tabnew = module.autocmd_base("tabnew"),
    tabnewentered = module.autocmd_base("tabnewentered"),
    tabclosed = module.autocmd_base("tabclosed"),
    termopen = module.autocmd_base("termopen"),
    termenter = module.autocmd_base("termenter"),
    termleave = module.autocmd_base("termleave"),
    termclose = module.autocmd_base("termclose"),
    termresponse = module.autocmd_base("termresponse"),
    textchanged = module.autocmd_base("textchanged"),
    textchangedi = module.autocmd_base("textchangedi"),
    textchangedp = module.autocmd_base("textchangedp"),
    user = module.autocmd_base("user"),
    usergettingbored = module.autocmd_base("usergettingbored"),
    vimenter = module.autocmd_base("vimenter"),
    vimleave = module.autocmd_base("vimleave"),
    vimleavepre = module.autocmd_base("vimleavepre"),
    vimresized = module.autocmd_base("vimresized"),
    vimresume = module.autocmd_base("vimresume"),
    vimsuspend = module.autocmd_base("vimsuspend"),
    winclosed = module.autocmd_base("winclosed"),
    winenter = module.autocmd_base("winenter"),
    winleave = module.autocmd_base("winleave"),
    winnew = module.autocmd_base("winnew"),
    winscrolled = module.autocmd_base("winscrolled"),
}

module.examples = {
    ["Binding to an Autocommand"] = function()
        local mymodule = neorg.modules.create("my.module")

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
            if event.type == "core.autocommands.events.insertleave" then
                log.warn("We left insert mode!")
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
