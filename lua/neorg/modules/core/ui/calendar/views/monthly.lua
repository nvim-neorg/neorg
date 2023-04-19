local module = neorg.modules.create('core.ui.calendar.views.monthly')

module.setup = function ()
    return {
        requires = {
            'core.ui.calendar'
        }
    }
end

module.private = {

}

module.public = {
    setup = function ()
        -- View setup function
    end
}

module.load = function ()
    module.required['core.ui.calendar'].add_view(module.public)
end

return module
