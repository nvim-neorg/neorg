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
	render = function(buffernr, png_path, position)
        local geometry =
        {
            x = position.column_start + vim.opt.numberwidth:get(),
            y = position.row_start+1,
            width = position.column_end - position.column_start,
            height = 1,
        }
		image = require("image").from_file(png_path, {
			buffer = buffernr,
            with_virtual_padding = true,
		})
		image:render(geometry) --geometry)
	end,
    clear = function()
        if not image then
            return
        end
        image:clear()
    end
}

return module
-- local renderer = neorg.modules.get_module(module.core.integrations.image)
