local module = neorg.modules.extend("core.concealer.ordered_prefix", "core.concealer")

module.config.private.icon_preset_basic = {}

return module

-- [ ] set ordering numerals on the fly
--- format: Neorg set-ordering-list-prefix nested ...
----- "§C.1.13"
----- 1) 1. a. (a) <a> 0 0. (0)
----- 1) 1.1)
----- id, separator, surrounding
----- (1.2.3.4)
----- 1. a. A. (a) (1) a) A) 0) i) I)
----- 1) 1a) 1b) 1.a) 1.3.5) A.3.5) (A.3.5)
-- vim.wo.concealcursor, visual mode
-- BufEnter/BufLeave toggle conceal
-- CursorHold
-- inccommand
--
--

local function render_roman_number_small(n)
    -- FIXME
    return ("i"):rep(math.min(n, 5))
end

local function render_roman_number_capital(n)
    local r = render_roman_number_small(n)
    return r and r:upper()
end

local function render_arabic_number_0b(n)
    assert(n >= 1)
    return tostring(n-1)
end

local function render_arabic_number_1b(n)
    assert(n >= 1)
    return tostring(n)
end

local function get_digit_infos(digit_tables)
    local result = {}
    for _, digit_table in pairs(digit_tables) do
        for start = 0, 1 do
            local char = digit_table[start]
            if not digit_table[start] then
                break
            end
            local function renderer(n)
                return digit_table[n - start]
            end
            table.insert(result, { char = char, renderer = renderer })
        end
    end
    table.insert(result, { char = '0', renderer = render_arabic_number_0b })
    table.insert(result, { char = '1', renderer = render_arabic_number_1b })
    table.insert(result, { char = 'i', renderer = render_roman_number_small })
    table.insert(result, { char = 'I', renderer = render_roman_number_capital })
end


local function parse_number_spec(number_spec, is_nested, digit_infos)
    local pos = {}
    for _, digit_info in pairs(digit_infos) do
        local l, r
        while true do
            l, r = str:find(number_spec, digit_info.char, l, true)
            if l == nil then
                break
            end
            table.insert(pos, { l = l, r = r, digit_info = digit_info })
            assert(l < r)
            l = r
        end
    end
    if #pos == 0 then
        return
    end

    table.sort(pos, function(p,q) return p.l < q.l end)
    local separators = {}
    local renderers = {}
    local prev_pos = 0
    for i = 1, #pos do
        assert(i==1 or pos[i-1].r <= pos[i].l)
        table.insert(separators, number_spec:sub(prev_pos, pos[i].l))
        table.insert(renderers, pos[i].renderer)
        prev_pos = pos[i].r
    end
    table.insert(separators, number_spec:sub(prev_pos))
    return { separators = separators, renderers = renderers }
end

