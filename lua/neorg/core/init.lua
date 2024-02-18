local neorg = {
    callbacks = require("neorg.core.callbacks"),
    config = require("neorg.core.config"),
    lib = require("lua-utils"),
    log = require("neorg.core.log"),
    modules = require("neorg.core.modules"),
    utils = require("neorg.core.utils"),
}

-- Try to connect to norgopolis

local norgopolis = require("norgopolis").connect("localhost")

norgopolis:invoke("hello-world", "echo", "this is a message from norgopolis!", function(ret)
    vim.print("Hello from norgopolis: " .. ret)
end)

return neorg
