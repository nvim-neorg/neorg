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
	render = function(buffernr, png_path, position, window, scale)
        local geometry =
        {
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
    clear = function()
        local images = require("image").get_images()
        for _, v in pairs(images) do
            v:clear()
        end
    end
}

return module
