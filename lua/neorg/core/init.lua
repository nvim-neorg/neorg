local neorg = {
    callbacks = require("neorg.core.callbacks"),
    config = require("neorg.core.config"),
    lib = assert(require("lua-utils"), "unable to find lua-utils dependency. Perhaps try restarting Neovim?"),
    log = require("neorg.core.log"),
    modules = require("neorg.core.modules"),
    utils = require("neorg.core.utils"),
}

return neorg
