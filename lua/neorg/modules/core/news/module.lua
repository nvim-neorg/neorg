require("neorg.external.log")

local module = neorg.modules.create("core.news")

module.setup = function()
    log.fatal("`core.news` has been deprecated since `v4.0.0`. Please remove the module from your configuration!")

    return {
        success = false,
    }
end

return module
