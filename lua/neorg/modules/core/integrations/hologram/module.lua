local module = neorg.modules.create("core.integrations.hologram")

module.load = function()
    local ok, hologram = pcall(require, "hologram")

    assert(ok)

    module.private.hologram = hologram
end

module.private = {
    hologram = nil,
}

module.public = {
    render = function(buffer, png_path, position)
        local image = require("hologram.image"):new(png_path, {})

        image:display(position.row_start, position.column_start, buffer, {
            data_width = position.column_end - position.column_start,
            data_height = 1,
        })
    end,
}

return module
