local neorg = require("neorg.core")
local module = neorg.modules.create("core.integrations.image")

module.load = function()
    local success, image = pcall(require, "image")

    assert(success, "Unable to loade image.nvim module")

    module.private.image = image
end

module.private = {
    image = nil,
}

module.public = {
    new_image = function(buffernr, png_path, position, window, scale)
        local geometry = {
            x = position.column_start + vim.opt.numberwidth:get(),
            y = position.row_start + 1,
            width = position.column_end - position.column_start,
            height = scale,
        }
        local image = require("image").from_file(png_path, {
            window = window,
            buffer = buffernr,
            with_virtual_padding = true,
        })
        image:render(geometry)
    end,
    get_images = function()
        return (require("image").get_images())
    end,
    render = function(images)
        for _, image in pairs(images) do
            image:clear()
            image:render()
        end
    end,
    clear = function()
        local images = module.public.get_images()
        for _, image in pairs(images) do
            image:clear()
        end
    end,
    clear_at_cursor = function(images, row)
        for _, image in pairs(images) do
            for k, v in pairs(image) do
                if k == "geometry" then
                    for k0, v0 in pairs(v) do
                        if k0 == "y" and v0 == row then
                            image:clear()
                        end
                    end
                end
            end
        end
    end,
}

return module
