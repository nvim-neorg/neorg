-- Define the base event, all events will derive from this by default
local base_event = {
    type = "core.base_event",
    split_type = {},
    content = nil,
    referrer = nil,
    broadcast = true,

    cursor_position = {},
    filename = "",
    filehead = "",
    line_content = "",
    buffer = 0,
    window = 0,
    mode = "",
}

return base_event
