local neorg = require("neorg.core")
local module = neorg.modules.create("core.integrations.image")

module.load = function()
    local success, image = pcall(require, "image")

    assert(success, "Unable to load image.nvim plugin")

    module.private.image = image
end

module.private = {
    image = nil,
}

module.public = {
    new_image = function(buffernr, png_path, position, window, scale, virtual_padding)
        local geometry = {
            x = position.column_start,
            y = position.row_start + (virtual_padding and 1 or 0),
            width = position.column_end - position.column_start,
            height = scale,
        }
        local image = require("image").from_file(png_path, {
            window = window,
            buffer = buffernr,
            with_virtual_padding = virtual_padding,
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
            if image.geometry.y == row then
                image:clear()
            end
        end
    end,
}

return module
