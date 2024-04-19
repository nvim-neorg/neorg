--[[
    file: Image
    title: Images Directly within Neovim.
    description: The `image` module uses various terminal backends to display images within your Neovim instance.
    summary: Module for interacting with and managing images in the terminal.
    internal: true
    ---

`core.integrations.image` is an internal module that wraps image.nvim, exposing methods to display images in neovim.
--]]

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
        local image = require("image").from_file(png_path, {
            window = window,
            buffer = buffernr,
            inline = true, -- let image.nvim track the position for us
            with_virtual_padding = virtual_padding,
            x = position.column_start,
            y = position.row_start + (virtual_padding and 1 or 0),
            width = position.column_end - position.column_start,
            height = scale,
        })
        -- image:render(geometry)
        return image
    end,
    ---Render an image or list of images
    ---@param images any[]
    render = function(images)
        for _, limage in pairs(images) do
            limage.image:clear()
            limage.image:render()
        end
    end,
    clear = function(images)
        for _, limage in pairs(images) do
            limage.image:clear()
        end
    end,
    clear_at_cursor = function(images, row)
        local cleared = {}
        for id, limage in pairs(images) do
            local image = limage.image
            if image.geometry.y == row then
                image:clear()
                table.insert(cleared, id)
            end
        end
        return cleared
    end,
}

return module
