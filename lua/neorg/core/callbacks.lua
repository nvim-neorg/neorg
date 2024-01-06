--- @brief [[
--- Defines user callbacks - ways for the user to directly interact with Neorg and respon on certain events.
--- @brief ]]

--- @class neorg.callbacks
local callbacks = {
    ---@type table<string, { [1]: fun(event: neorg.event, content: table|any), [2]?: fun(event: neorg.event): boolean }>
    callback_list = {},
}

--- Triggers a new callback to execute whenever an event of the requested type is executed.
--- @param event_name string The full path to the event we want to listen on.
--- @param callback fun(event: neorg.event, content: table|any) The function to call whenever our event gets triggered.
--- @param content_filter fun(event: neorg.event): boolean # A filtering function to test if a certain event meets our expectations.
function callbacks.on_event(event_name, callback, content_filter)
    -- If the table doesn't exist then create it
    callbacks.callback_list[event_name] = callbacks.callback_list[event_name] or {}
    -- Insert the callback and content filter
    table.insert(callbacks.callback_list[event_name], { callback, content_filter })
end

--- Used internally by Neorg to call all callbacks with an event.
--- @param event neorg.event An event as returned by `modules.create_event()`
--- @see modules.create_event
function callbacks.handle_callbacks(event)
    -- Query the list of registered callbacks
    local callback_entry = callbacks.callback_list[event.type]

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

return callbacks
