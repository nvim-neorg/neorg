--[[
--	AUTOCOMMAND MODULE FOR NEORG
--	This module exposes functionality for subscribing to autocommands and performing actions based on those autocommands

USAGE:

	In your module.setup(), make sure to require core.autocommands (requires = { "core.autocommands" })
	Afterwards in a function of your choice that gets called *after* core.autocommmands gets intialized e.g. load():

	module.load = function()
		module.required["core.autocommands"].enable_autocommand("VimLeavePre") -- Substitute VimLeavePre for any valid neovim autocommand
	end

	Afterwards, be sure to subscribe to the event:

	module.events.subscribed = {

		["core.autocommands"] = {
			vimleavepre = true
		}

	}

	Upon receiving an event, it will come in this format:
	{
		type = "core.autocommands.events.<name of autocommand, e.g. vimleavepre>",
		broadcast = true
	}

--]]

require('neorg.modules.base')
require('neorg.events')

local module_autocommands = neorg.modules.create("core.autocommands")

-- @Summary Autocommand callback
-- @Description This function gets invoked whenever a core.autocommands enabled autocommand is triggered. Note that this function should be only used internally
-- @Param  name (string) - the name of the autocommand that was just triggered
function _neorg_module_autocommand_triggered(name)
	neorg.events.broadcast_event(neorg.events.create(module_autocommands, name))
end

-- A convenience wrapper around neorg.events.define_event
module_autocommands.autocmd_base = function(name) return neorg.events.define(module_autocommands, name) end

module_autocommands.public = {

	-- @Summary Enable an autocommand event
	-- @Description By default, all autocommands are disabled for performance reasons. To enable them, use this command. If an invalid autocmd is given nothing happens.
	-- @Param  autocmd (string) - the relative name of the autocommand to enable
	-- @Param  dont_isolate (boolean) - defaults to false. Specifies whether the autocommand should run globally (*) instead of in Neorg files (*.norg)
	enable_autocommand = function(autocmd, dont_isolate)
		dont_isolate = dont_isolate or false

		autocmd = autocmd:lower()
		local subscribed_autocommand = module_autocommands.events.subscribed["core.autocommands"][autocmd]

		if subscribed_autocommand ~= nil then
			if subscribed_autocommand == false then
				vim.cmd("augroup Neorg")
				if dont_isolate then
					vim.cmd("autocmd " .. autocmd .. " * :lua _neorg_module_autocommand_triggered(\"core.autocommands.events." .. autocmd .. "\")")
				else
					vim.cmd("autocmd " .. autocmd .. " *.norg :lua _neorg_module_autocommand_triggered(\"core.autocommands.events." .. autocmd .. "\")")
				end
				vim.cmd("augroup END")
				module_autocommands.events.subscribed["core.autocommands"][autocmd] = true
			end
		end
	end,

	version = "0.0.9"

}

-- All the subscribeable events for core.autocommands
module_autocommands.events.subscribed = {

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
		winscrolled = false

	}
}

-- All the autocommand definitions
module_autocommands.events.defined = {

	bufadd = module_autocommands.autocmd_base("bufadd"),
	bufdelete = module_autocommands.autocmd_base("bufdelete"),
	bufenter = module_autocommands.autocmd_base("bufenter"),
	buffilepost = module_autocommands.autocmd_base("buffilepost"),
	buffilepre = module_autocommands.autocmd_base("buffilepre"),
	bufhidden = module_autocommands.autocmd_base("bufhidden"),
	bufleave = module_autocommands.autocmd_base("bufleave"),
	bufmodifiedset = module_autocommands.autocmd_base("bufmodifiedset"),
	bufnew = module_autocommands.autocmd_base("bufnew"),
	bufnewfile = module_autocommands.autocmd_base("bufnewfile"),
	bufread = module_autocommands.autocmd_base("bufread"),
	bufreadcmd = module_autocommands.autocmd_base("bufreadcmd"),
	bufreadpre = module_autocommands.autocmd_base("bufreadpre"),
	bufunload = module_autocommands.autocmd_base("bufunload"),
	bufwinenter = module_autocommands.autocmd_base("bufwinenter"),
	bufwinleave = module_autocommands.autocmd_base("bufwinleave"),
	bufwipeout = module_autocommands.autocmd_base("bufwipeout"),
	bufwrite = module_autocommands.autocmd_base("bufwrite"),
	bufwritecmd = module_autocommands.autocmd_base("bufwritecmd"),
	bufwritepost = module_autocommands.autocmd_base("bufwritepost"),
	chaninfo = module_autocommands.autocmd_base("chaninfo"),
	chanopen = module_autocommands.autocmd_base("chanopen"),
	cmdundefined = module_autocommands.autocmd_base("cmdundefined"),
	cmdlinechanged = module_autocommands.autocmd_base("cmdlinechanged"),
	cmdlineenter = module_autocommands.autocmd_base("cmdlineenter"),
	cmdlineleave = module_autocommands.autocmd_base("cmdlineleave"),
	cmdwinenter = module_autocommands.autocmd_base("cmdwinenter"),
	cmdwinleave = module_autocommands.autocmd_base("cmdwinleave"),
	colorscheme = module_autocommands.autocmd_base("colorscheme"),
	colorschemepre = module_autocommands.autocmd_base("colorschemepre"),
	completechanged = module_autocommands.autocmd_base("completechanged"),
	completedonepre = module_autocommands.autocmd_base("completedonepre"),
	completedone = module_autocommands.autocmd_base("completedone"),
	cursorhold = module_autocommands.autocmd_base("cursorhold"),
	cursorholdi = module_autocommands.autocmd_base("cursorholdi"),
	cursormoved = module_autocommands.autocmd_base("cursormoved"),
	cursormovedi = module_autocommands.autocmd_base("cursormovedi"),
	diffupdated = module_autocommands.autocmd_base("diffupdated"),
	dirchanged = module_autocommands.autocmd_base("dirchanged"),
	fileappendcmd = module_autocommands.autocmd_base("fileappendcmd"),
	fileappendpost = module_autocommands.autocmd_base("fileappendpost"),
	fileappendpre = module_autocommands.autocmd_base("fileappendpre"),
	filechangedro = module_autocommands.autocmd_base("filechangedro"),
	exitpre = module_autocommands.autocmd_base("exitpre"),
	filechangedshell = module_autocommands.autocmd_base("filechangedshell"),
	filechangedshellpost = module_autocommands.autocmd_base("filechangedshellpost"),
	filereadcmd = module_autocommands.autocmd_base("filereadcmd"),
	filereadpost = module_autocommands.autocmd_base("filereadpost"),
	filereadpre = module_autocommands.autocmd_base("filereadpre"),
	filetype = module_autocommands.autocmd_base("filetype"),
	filewritecmd = module_autocommands.autocmd_base("filewritecmd"),
	filewritepost = module_autocommands.autocmd_base("filewritepost"),
	filewritepre = module_autocommands.autocmd_base("filewritepre"),
	filterreadpost = module_autocommands.autocmd_base("filterreadpost"),
	filterreadpre = module_autocommands.autocmd_base("filterreadpre"),
	filterwritepost = module_autocommands.autocmd_base("filterwritepost"),
	filterwritepre = module_autocommands.autocmd_base("filterwritepre"),
	focusgained = module_autocommands.autocmd_base("focusgained"),
	focuslost = module_autocommands.autocmd_base("focuslost"),
	funcundefined = module_autocommands.autocmd_base("funcundefined"),
	uienter = module_autocommands.autocmd_base("uienter"),
	uileave = module_autocommands.autocmd_base("uileave"),
	insertchange = module_autocommands.autocmd_base("insertchange"),
	insertcharpre = module_autocommands.autocmd_base("insertcharpre"),
	textyankpost = module_autocommands.autocmd_base("textyankpost"),
	insertenter = module_autocommands.autocmd_base("insertenter"),
	insertleavepre = module_autocommands.autocmd_base("insertleavepre"),
	insertleave = module_autocommands.autocmd_base("insertleave"),
	menupopup = module_autocommands.autocmd_base("menupopup"),
	optionset = module_autocommands.autocmd_base("optionset"),
	quickfixcmdpre = module_autocommands.autocmd_base("quickfixcmdpre"),
	quickfixcmdpost = module_autocommands.autocmd_base("quickfixcmdpost"),
	quitpre = module_autocommands.autocmd_base("quitpre"),
	remotereply = module_autocommands.autocmd_base("remotereply"),
	sessionloadpost = module_autocommands.autocmd_base("sessionloadpost"),
	shellcmdpost = module_autocommands.autocmd_base("shellcmdpost"),
	signal = module_autocommands.autocmd_base("signal"),
	shellfilterpost = module_autocommands.autocmd_base("shellfilterpost"),
	sourcepre = module_autocommands.autocmd_base("sourcepre"),
	sourcepost = module_autocommands.autocmd_base("sourcepost"),
	sourcecmd = module_autocommands.autocmd_base("sourcecmd"),
	spellfilemissing = module_autocommands.autocmd_base("spellfilemissing"),
	stdinreadpost = module_autocommands.autocmd_base("stdinreadpost"),
	stdinreadpre = module_autocommands.autocmd_base("stdinreadpre"),
	swapexists = module_autocommands.autocmd_base("swapexists"),
	syntax = module_autocommands.autocmd_base("syntax"),
	tabenter = module_autocommands.autocmd_base("tabenter"),
	tableave = module_autocommands.autocmd_base("tableave"),
	tabnew = module_autocommands.autocmd_base("tabnew"),
	tabnewentered = module_autocommands.autocmd_base("tabnewentered"),
	tabclosed = module_autocommands.autocmd_base("tabclosed"),
	termopen = module_autocommands.autocmd_base("termopen"),
	termenter = module_autocommands.autocmd_base("termenter"),
	termleave = module_autocommands.autocmd_base("termleave"),
	termclose = module_autocommands.autocmd_base("termclose"),
	termresponse = module_autocommands.autocmd_base("termresponse"),
	textchanged = module_autocommands.autocmd_base("textchanged"),
	textchangedi = module_autocommands.autocmd_base("textchangedi"),
	textchangedp = module_autocommands.autocmd_base("textchangedp"),
	user = module_autocommands.autocmd_base("user"),
	usergettingbored = module_autocommands.autocmd_base("usergettingbored"),
	vimenter = module_autocommands.autocmd_base("vimenter"),
	vimleave = module_autocommands.autocmd_base("vimleave"),
	vimleavepre = module_autocommands.autocmd_base("vimleavepre"),
	vimresized = module_autocommands.autocmd_base("vimresized"),
	vimresume = module_autocommands.autocmd_base("vimresume"),
	vimsuspend = module_autocommands.autocmd_base("vimsuspend"),
	winclosed = module_autocommands.autocmd_base("winclosed"),
	winenter = module_autocommands.autocmd_base("winenter"),
	winleave = module_autocommands.autocmd_base("winleave"),
	winnew = module_autocommands.autocmd_base("winnew"),
	winscrolled = module_autocommands.autocmd_base("winscrolled")

}

return module_autocommands
