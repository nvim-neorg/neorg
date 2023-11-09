local modules = require("neorg.core.modules")
local api, fn = vim.api, vim.fn


---@class neorg.events
---# A simple interface to publish event samples.
---
---## Events and event samples
---An event is a point in the flow of Neorg's execution that one of its modules
---broadcasts so that other modules can react accordingly. Events follow a simple
---publish-subscribe model where publishers send the event to all loaded modules
---and those react to the event if they are subscribed to the event's topic.
---
---An event sample is an aggregation of data sent when an event is published, i.e.
---when the function `events.publish` is called by a module.
---
---## Topic names
---The topic name can be namespaced by prepending as many namespaces as desired
---separated by a dot (`.`). For example, you can namespace `"my_event"` as
---`"my_namespace.my_event"`. This namespacing scheme shall never be used to
---identify the publisher of the event. If the publisher should ever require
---identification, a discriminator should be included in the payload.
---
---## Payloads
---All samples contain a payload, whose type is identified by the sample's topic.
---A topic is a string that uniquely identifies the sample's type. When a module
---subscribes to a type of event, they subscribe to its topic. For example, a
---module can be subscribed to the topic `"module_loaded"` and not be subscribed
---to `"autocmd"`. When a module is subscribed to a topic, it knows exactly the
---fields that its corresponding sample's payload will have when it is received.
---This also implies that different topics can have the same type, but a topic's
---type must always be the same in every event sample.
---
---When you define your event's type with LuaLS, call it `neorg.event.<topic_name>`.
---For example, the event whose topic name is `"neorg_started"` should be of
---type `neorg.event.neorg_started`.
---
---### Making LuaLS aware of the type of the payload
---When you call `events.publish`, you can build the payload in-place as an
---argument for the function. If you do it this way, you can add an `@as` type
---hint after the table's closing bracket to enable completion and diagnostics:
---
---```lua
---events.publish("core.concealer.update_region", {
---    start = start_pos[1] - 1,
---    ["end"] = end_pos[1] + 2,
---} --[[@as neorg.event.core.concealer.update_region]])
---```
---
---## Notes on the publish-subscribe system
---When an event is published, it is published for every single loaded module.
---It is every module's responsibility to subscribe to the topics it is
---interested in and properly handle the samples it receives. This is integral to
---the correct functioning of the events system, since the responsibility also
---gives the subscribers the power to extend Neorg's functionality by
---implementing new behaviours based on the events published by different modules.
---
---If an event could be published but it shouldn't be received by any subscriber,
---it is the publisher's responsibility to prevent the publication of such event.
local events = {}


---@class neorg.event_sample
---@field public topic string #An unique name that identifies the event's payload type
---@field public payload any #The content of the event, identified by the `topic` discriminator field
---@field public cursor_position cursor_pos #The position of the cursor when the event was published
---@field public filename string #The name of the active file when the event was published
---@field public filehead string #The absolute path of the active file's directory when the event was published
---@field public line_content string #The content of the active line when the event was published
---@field public buffer integer #The active buffer descriptor when the event was published
---@field public window integer #The active window descriptor when the event was published
---@field public mode string #Vim's mode when the event was published


---Publish an event that is received by all modules. See the documentation for
---`neorg.events` for more information on the publishing and subscribing rules.
---@param topic string #See event_sample::topic
---@param payload any #See event_sample::payload
function events.publish(topic, payload)
    local event --[[@as neorg.event_sample]] = {
        topic = topic,
        payload = payload,

        -- Metadata members defining Vim's state when the event was published
        -- TODO: Deprecate? These could be added to the payload on demand.
        cursor_position = vim.api.nvim_win_get_cursor(0),
        filename = fn.expand("%:t"),
        filehead = fn.expand("%:p:h"),
        line_content = api.nvim_get_current_line(),
        buffer = api.nvim_get_current_buf(),
        window = api.nvim_get_current_win(),
        mode = api.nvim_get_mode().mode,
    }

    for _, module in pairs(modules.loaded_modules) do
        module:on_event(event)
    end
end


return events
