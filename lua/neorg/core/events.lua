local callbacks = require("neorg.core.callbacks")

local api = vim.api
local fn = vim.fn


---@class event.base
---@field public referrer table? #A reference to the module invoking the function
---@field public name string #The name of the event, effectively its type within its referrer module
---@field public payload any #The content of the event, it can by anything the handler will interpret
--- This class defined the bare minimum information and behaviour an event can
--- have. When an event is created, the functions will need to be copied and
--- the relevant base members initialised.
local base_event = {}


--- Sends the event to all subscribed modules in a list. This will usually be
--- `neorg.modules.loaded_modules`, but the list can be curated by the referrer.
---@param self event
---@param modules vec<table> #Currently loaded modules
---@param callback function? #A callback to be invoked after all events have been asynchronously broadcast
function base_event:broadcast(modules, callback)
    callbacks.handle_callbacks(self)

    for _, module in pairs(modules) do
        -- If `module` has a subscription bound to the broadcaster's referrer
        -- and that subscription is currently active, run `on_event` for `module`.
        local subscription = module.events.subscribed[self.referrer.name]
        if subscription and subscription[self.name] then
            module.on_event(self)
        end
    end

    -- Because the broadcasting of events is async we allow the event broadcaster to provide a callback
    -- TODO: deprecate
    if callback then
        callback()
    end
end


--- Send the event to a single module. This function is just an alias of
--- broadcast with one recipient for semantic convenience.
---@param self event
---@param recipient table #The module that will be the recipient of the event
function base_event:send_to(recipient)
    self:broadcast({recipient})
end


---@class event: event.base
---@field public cursor_position cursor_pos #The position of the cursor when the event was fired
---@field public filename string #The name of the active file when the event was fired
---@field public filehead string #The absolute path of the active file's directory when the event was fired
---@field public line_content string #The content of the active line when the event was fired
---@field public buffer integer #The active buffer descriptor when the event was fired
---@field public window integer #The active window descriptor when the event was fired
---@field public mode string #Vim's mode when the event was fired


local events = {}


--- Creates a new event fired by a module.
---@param referrer table #See event::referrer
---@param name string #See event::name
---@param payload any #See event::payload
---@return event #The newly created event
function events.new(referrer, name, payload)
    return {
        -- Members intialised directly from function arguments
        referrer = referrer,
        name = name,
        payload = payload,

        -- Members defining Vim's state when the event was fired
        cursor_position = vim.api.nvim_win_get_cursor(0),
        filename = fn.expand("%:t"),
        filehead = fn.expand("%:p:h"),
        line_content = api.nvim_get_current_line(),
        buffer = api.nvim_get_current_buf(),
        window = api.nvim_get_current_win(),
        mode = api.nvim_get_mode().mode,

        -- Base event member functions
        broadcast = base_event.broadcast,
        send_to = base_event.send_to,
    }
end


--- Creates a quick event fired by a module. Quick events are events that don't
--- take the user's current context into account.
---@param referrer table #See event::referrer
---@param name string #See event::name
---@param payload any #See event::payload
---@return event.base #The newly created quick event
function events.new_quick(referrer, name, payload)
    return {
        -- Members intialised directly from function arguments
        referrer = referrer,
        name = name,
        payload = payload,

        -- Base event member functions
        broadcast = base_event.broadcast,
        send_to = base_event.send_to,
    }
end


return events
