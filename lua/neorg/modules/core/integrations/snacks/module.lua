-- lua/neorg/modules/core/integrations/snacks/module.lua
local neorg = require("neorg.core")
local module = neorg.modules.create("core.integrations.snacks")

module.setup = function()
    return { success = true, requires = {} }
end

module.load = function()
    local ok_snacks, snacks = pcall(require, "snacks")
    local ok_image, image = pcall(require, "image")
    
    module.private = {
        snacks = ok_snacks and snacks or nil,
        image = ok_image and image or nil,
    }
end

module.private = module.private or {}

-- Helper: Wrapper that can "Resurrect" Snacks images
-- This is crucial because Snacks images are often destroyed when closed.
-- We capture the 'factory' function to re-create the image whenever render() is called.
local function create_resurrectable_wrapper(factory_func, initial_geometry)
    return {
        _img = nil, -- Starts empty, created on first render
        geometry = initial_geometry, 
        factory = factory_func,

        render = function(self, coords)
            -- 1. Resurrect the image if it's missing (was cleared/closed)
            if not self._img then
                local ok, img = pcall(self.factory)
                if ok and img then
                    self._img = img
                else
                    return -- Creation failed, nothing to render
                end
            end
            
            -- 2. Update coordinates
            if coords and coords.x then self.geometry.x = coords.x end
            if coords and coords.y then self.geometry.y = coords.y end
            
            -- 3. Translate Neorg (0-based) to Snacks (1-based row)
            local row = (coords and coords.y or self.geometry.y) + 1
            local col = (coords and coords.x or self.geometry.x)
            
            -- 4. Move/Update the underlying Snacks image
            pcall(function()
                if self._img.opts then self._img.opts.pos = { row, col } end
                
                if self._img.update then self._img:update()
                elseif self._img.moveto then self._img:moveto(row, col)
                end
            end)
        end,
        
        clear = function(self)
            -- When clearing, we CLOSE the image to remove it from screen/memory.
            -- We set _img to nil so next render() knows to re-create it.
            if self._img then
                pcall(function() 
                    if self._img.close then self._img:close() 
                    elseif self._img.clear then self._img:clear() end
                end)
                self._img = nil
            end
        end,
        
        image_width = initial_geometry.width,
        image_height = initial_geometry.height
    }
end

module.public = {}

module.public.new_image = function(buffernr, png_path, position, window, scale, virtual_padding)
    local r_start = position.row_start or position[1] or 0
    local c_start = position.column_start or position[2] or 0
    local x_pos = c_start
    local y_pos = r_start + (virtual_padding and 1 or 0)

    -- 1. Try Snacks.nvim
    if module.private.snacks then
        local snacks_image = module.private.snacks.image
        local constructor = nil
        
        -- Detect constructor
        if snacks_image then
            if type(snacks_image.new) == "function" then constructor = snacks_image.new
            elseif snacks_image.placement and type(snacks_image.placement.new) == "function" then constructor = snacks_image.placement.new
            elseif getmetatable(snacks_image) and getmetatable(snacks_image).__call then constructor = snacks_image end
        end

        if constructor then
            -- Define the Factory Function (Closure)
            -- This captures all params needed to create the image later
            local image_factory = function()
                local opts = {
                    window = window,
                    inline = true,
                    pos = { y_pos + 1, x_pos },
                    height = scale,
                    max_width = 100,
                    conceal = true,
                }
                
                -- Try dual signatures (User-reported vs Standard)
                local ok, img = pcall(constructor, buffernr, png_path, opts)
                if not (ok and img) then
                    -- Fallback to standard signature
                    local opts2 = vim.tbl_deep_extend("force", opts, { buffer = buffernr })
                    img = constructor(png_path, opts2)
                end
                return img
            end

            -- Try creating once to get dimensions and validate
            local ok, result_img = pcall(image_factory)
            
            if ok and result_img then
                -- Extract dimensions safely
                local w, h = 100, 100
                if result_img.meta then
                    w = result_img.meta.width or w
                    h = result_img.meta.height or h
                elseif result_img.image_width then
                     w = result_img.image_width
                     h = result_img.image_height
                end

                -- Return the wrapper, passing the factory
                local wrapper = create_resurrectable_wrapper(image_factory, { x = x_pos, y = y_pos, width = w, height = h })
                
                -- Assign the initially created image to the wrapper so it's ready
                wrapper._img = result_img
                return wrapper
            end
        end
    end

    -- 2. Fallback to Image.nvim
    if module.private.image then
        local ok, img = pcall(function()
            return module.private.image.from_file(png_path, {
                window = window,
                buffer = buffernr,
                inline = true,
                with_virtual_padding = virtual_padding,
                x = x_pos,
                y = y_pos,
                height = scale,
            })
        end)
        if ok and img then return img end
    end

    return nil
end

module.public.render = function(images)
    for _, limage in pairs(images) do
        local img_obj = limage.image or limage
        pcall(function()
            if img_obj.render then
                img_obj:render({ y = limage.range[1], x = limage.range[2] })
            elseif img_obj.geometry and img_obj.geometry.render then
                img_obj.geometry:render({ y = limage.range[1], x = limage.range[2] })
            end
        end)
    end
end

module.public.clear = function(images)
    for _, limage in pairs(images) do
        local img_obj = limage.image or limage
        pcall(function()
            if img_obj.clear then img_obj:clear()
            elseif img_obj.remove then img_obj:remove()
            end
        end)
    end
end

module.public.clear_at_cursor = function(images, row)
    local cleared = {}
    for id, limage in pairs(images) do
        local img_obj = limage.image or limage
        local y = nil
        if img_obj.geometry and img_obj.geometry.y then y = img_obj.geometry.y
        elseif img_obj.y then y = img_obj.y
        end
        if y == row then
            pcall(function()
                if img_obj.clear then img_obj:clear()
                elseif img_obj.remove then img_obj:remove()
                end
            end)
            table.insert(cleared, id)
        end
    end
    return cleared
end

module.public.image_size = function(image, limit)
    limit = limit or {}
    local img_w = 100
    local img_h = 100

    if image.image_width then img_w = image.image_width end
    if image.image_height then img_h = image.image_height end
    if image._img and image._img.meta then
         img_w = image._img.meta.width or img_w
         img_h = image._img.meta.height or img_h
    end

    local cell_w, cell_h = 10, 20
    pcall(function()
        local term_size = require("image.utils.term").get_size()
        cell_w = term_size.cell_width
        cell_h = term_size.cell_height
    end)

    local true_size = {
        width = math.min(math.floor(img_w / cell_w), limit.width or math.huge),
        height = math.min(math.floor(img_h / cell_h), limit.height or math.huge),
    }
    
    local ratio = img_w / img_h
    local width = true_size.width
    local height = true_size.height
    
    if width / height > ratio then width = height * ratio
    else height = width / ratio end

    return { width = math.max(1, math.ceil(width)), height = math.max(1, math.ceil(height)) }
end

return module
