--[[
    Neorg User Callbacks File
    User callbacks are ways for the user to directly interact with Neorg and respond on certain events.
--]]

---@diagnostic disable-next-line: lowercase-global
neorg = {}

neorg.callbacks = {
    callback_list = {},
}

--- Triggers a new callback to execute whenever an event of the requested type is executed
---@param event_name string #The full path to the event we want to listen on
---@param callback fun(event, content) #The function to call whenever our event gets triggered
---@param content_filter fun(event) #A filtering function to test if a certain event meets our expectations
function neorg.callbacks.on_event(event_name, callback, content_filter)
    -- If the table doesn't exist then create it
    neorg.callbacks.callback_list[event_name] = neorg.callbacks.callback_list[event_name] or {}
    -- Insert the callback and content filter
    table.insert(neorg.callbacks.callback_list[event_name], { callback, content_filter })
end

--- Used internally by Neorg to call all callbacks with an event
---@param event table #An event as returned by neorg.events.create()
function neorg.callbacks.handle_callbacks(event)
    -- Query the list of registered callbacks
    local callback_entry = neorg.callbacks.callback_list[event.type]

    -- If the callbacks exist then
    if callback_entry then
        -- Loop through every callback
        for _, callback in ipairs(callback_entry) do
            -- If the filter event has not been defined or if the filter returned true then
            if not callback[2] or callback[2](event) then
                -- Execute the callback
                callback[1](event, event.content)
            end
        end
    end
end

return neorg.callbacks
