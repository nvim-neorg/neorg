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
    module.private.image_utils = require("image.utils")
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
            height = scale,
        })
        return image
    end,
    ---Render an image or list of images
    ---@param images any[]
    render = function(images)
        for _, limage in pairs(images) do
            limage.image:render({ y = limage.range[1], x = limage.range[2] })
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
    ---Compute the image's rendered width/height without rendering
    ---@param image any an image.nvim image
    ---@param limit { width: number, height: number }
    ---@return { width: number, height: number }
    image_size = function(image, limit)
        limit = limit or {}
        local term_size = require("image.utils.term").get_size()
        local gopts = image.global_state.options

        local true_size = {
            width = math.min(
                math.floor(image.image_width / term_size.cell_width), -- max image size (images don't scale up past their true size)
                gopts.max_width or math.huge, -- image.nvim configured max size
                limit.width or math.huge -- latex-renderer configured max size
            ),
            height = math.min(
                math.floor(image.image_height / term_size.cell_height),
                gopts.max_height or math.huge,
                limit.height or math.huge
            ),
        }
        local width, height = module.private.image_utils.math.adjust_to_aspect_ratio(
            term_size,
            image.image_width,
            image.image_height,
            true_size.width,
            true_size.height
        )
        return { width = math.ceil(width), height = math.ceil(height) }
    end,
}

return module
