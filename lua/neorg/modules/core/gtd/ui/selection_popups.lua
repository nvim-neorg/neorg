return function(module)
    return {
        public = {
            show_quick_actions = function(configs)
                -- Generate quick_actions selection popup
                local buffer = module.required["core.ui"].create_split("Quick Actions")
                local selection = module.required["core.ui"].begin_selection(buffer):add_listener(
                    "destroy",
                    { "<Esc>" },
                    function(self)
                        self:destroy()
                    end
                )

                selection
                    :title("Quick Actions")
                    :blank()
                    :text("Capture")
                    :concat(module.private.add_to_inbox)
                    :blank()
                    :text("Displays")
                    :concat(function(_selection)
                        return module.private.generate_display_flags(_selection, configs)
                    end)
            end,
        },
    }
end
