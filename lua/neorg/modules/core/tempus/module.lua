--[[
    file: Tempus
    title: Hassle-Free Dates
    summary: Parses and handles dates in Neorg.
    internal: true
    ---
`core.tempus` is an internal module specifically designed
to handle complex dates. It exposes two functions: `parse_date(string) -> date|string`
and `to_lua_date(date) -> osdate`.
--]]

local neorg = require("neorg.core")
local lib, modules, utils = neorg.lib, neorg.modules, neorg.utils

local module = modules.create("core.tempus")

assert(vim.re ~= nil, "Neovim 0.10.0+ is required to run the `core.tempus` module! ")

-- NOTE: Maybe encapsulate whole date parser in a single PEG grammar?
local _, time_regex = pcall(vim.re.compile, [[{%d%d?} ":" {%d%d} ("." {%d%d?})?]])

local timezone_list = {
    "ACDT",
    "ACST",
    "ACT",
    "ACWST",
    "ADT",
    "AEDT",
    "AEST",
    "AET",
    "AFT",
    "AKDT",
    "AKST",
    "ALMT",
    "AMST",
    "AMT",
    "ANAT",
    "AQTT",
    "ART",
    "AST",
    "AWST",
    "AZOST",
    "AZOT",
    "AZT",
    "BNT",
    "BIOT",
    "BIT",
    "BOT",
    "BRST",
    "BRT",
    "BST",
    "BTT",
    "CAT",
    "CCT",
    "CDT",
    "CEST",
    "CET",
    "CHADT",
    "CHAST",
    "CHOT",
    "CHOST",
    "CHST",
    "CHUT",
    "CIST",
    "CKT",
    "CLST",
    "CLT",
    "COST",
    "COT",
    "CST",
    "CT",
    "CVT",
    "CWST",
    "CXT",
    "DAVT",
    "DDUT",
    "DFT",
    "EASST",
    "EAST",
    "EAT",
    "ECT",
    "EDT",
    "EEST",
    "EET",
    "EGST",
    "EGT",
    "EST",
    "ET",
    "FET",
    "FJT",
    "FKST",
    "FKT",
    "FNT",
    "GALT",
    "GAMT",
    "GET",
    "GFT",
    "GILT",
    "GIT",
    "GMT",
    "GST",
    "GYT",
    "HDT",
    "HAEC",
    "HST",
    "HKT",
    "HMT",
    "HOVST",
    "HOVT",
    "ICT",
    "IDLW",
    "IDT",
    "IOT",
    "IRDT",
    "IRKT",
    "IRST",
    "IST",
    "JST",
    "KALT",
    "KGT",
    "KOST",
    "KRAT",
    "KST",
    "LHST",
    "LINT",
    "MAGT",
    "MART",
    "MAWT",
    "MDT",
    "MET",
    "MEST",
    "MHT",
    "MIST",
    "MIT",
    "MMT",
    "MSK",
    "MST",
    "MUT",
    "MVT",
    "MYT",
    "NCT",
    "NDT",
    "NFT",
    "NOVT",
    "NPT",
    "NST",
    "NT",
    "NUT",
    "NZDT",
    "NZST",
    "OMST",
    "ORAT",
    "PDT",
    "PET",
    "PETT",
    "PGT",
    "PHOT",
    "PHT",
    "PHST",
    "PKT",
    "PMDT",
    "PMST",
    "PONT",
    "PST",
    "PWT",
    "PYST",
    "PYT",
    "RET",
    "ROTT",
    "SAKT",
    "SAMT",
    "SAST",
    "SBT",
    "SCT",
    "SDT",
    "SGT",
    "SLST",
    "SRET",
    "SRT",
    "SST",
    "SYOT",
    "TAHT",
    "THA",
    "TFT",
    "TJT",
    "TKT",
    "TLT",
    "TMT",
    "TRT",
    "TOT",
    "TVT",
    "ULAST",
    "ULAT",
    "UTC",
    "UYST",
    "UYT",
    "UZT",
    "VET",
    "VLAT",
    "VOLT",
    "VOST",
    "VUT",
    "WAKT",
    "WAST",
    "WAT",
    "WEST",
    "WET",
    "WIB",
    "WIT",
    "WITA",
    "WGST",
    "WGT",
    "WST",
    "YAKT",
    "YEKT",
}

---@alias Date {weekday: {name: string, number: number}?, day: number?, month: {name: string, number: number}?, year: number?, timezone: string?, time: {hour: number, minute: number, second: number?}?}

---@class core.tempus
module.public = {
    --- Converts a parsed date with `parse_date` to a lua date.
    ---@param parsed_date Date #The date to convert
    ---@return osdate #A Lua date
    to_lua_date = function(parsed_date)
        return os.date( ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
            "*t",
            os.time(
                vim.tbl_deep_extend(
                    "force",
                    os.date("*t"),
                    { ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
                        day = parsed_date.day,
                        month = parsed_date.month and parsed_date.month.number or nil,
                        year = parsed_date.year,
                        hour = parsed_date.time and parsed_date.time.hour,
                        min = parsed_date.time and parsed_date.time.minute,
                        sec = parsed_date.time and parsed_date.time.second,
                    }
                )
            )
        )
    end,

    --- Converts a lua `osdate` to a Neorg date.
    ---@param osdate osdate #The date to convert
    ---@param include_time boolean? #Whether to include the time (hh::mm.ss) in the output.
    ---@return Date #The converted date
    to_date = function(osdate, include_time)
        -- TODO: Extract into a function to get weekdays (have to hot recalculate every time because the user may change locale
        local weekdays = {}
        for i = 1, 7 do
            table.insert(weekdays, os.date("%A", os.time({ year = 2000, month = 5, day = i })):lower()) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        end

        local months = {}
        for i = 1, 12 do
            table.insert(months, os.date("%B", os.time({ year = 2000, month = i, day = 1 })):lower()) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        end

        -- os.date("*t") returns wday with Sunday as 1, needs to be
        -- converted to Monday as 1
        local converted_weekday = lib.number_wrap(osdate.wday - 1, 1, 7)

        return module.private.tostringable_date({
            weekday = osdate.wday and {
                number = converted_weekday,
                name = lib.title(weekdays[converted_weekday]),
            } or nil,
            day = osdate.day,
            month = osdate.month and {
                number = osdate.month,
                name = lib.title(months[osdate.month]),
            } or nil,
            year = osdate.year,
            time = osdate.hour and setmetatable({
                hour = osdate.hour,
                minute = osdate.min or 0,
                second = osdate.sec or 0,
            }, {
                __tostring = function()
                    if not include_time then
                        return ""
                    end

                    return tostring(osdate.hour)
                        .. ":"
                        .. tostring(string.format("%02d", osdate.min))
                        .. (osdate.sec ~= 0 and ("." .. tostring(osdate.sec)) or "")
                end,
            }) or nil,
        })
    end,

    --- Parses a date and returns a table representing the date
    ---@param input string #The input which should follow the date specification found in the Norg spec.
    ---@return Date|string #The data extracted from the input or an error message
    parse_date = function(input)
        local weekdays = {}
        for i = 1, 7 do
            table.insert(weekdays, os.date("%A", os.time({ year = 2000, month = 5, day = i })):lower()) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        end

        local months = {}
        for i = 1, 12 do
            table.insert(months, os.date("%B", os.time({ year = 2000, month = i, day = 1 })):lower()) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        end

        local output = {}

        for word in vim.gsplit(input, "%s+") do
            if word:len() == 0 then
                goto continue
            end

            if word:match("^-?%d%d%d%d+$") then
                output.year = tonumber(word)
            elseif word:match("^%d+%w*$") then
                output.day = tonumber(word:match("%d+"))
            elseif vim.list_contains(timezone_list, word:upper()) then
                output.timezone = word:upper()
            else
                do
                    local hour, minute, second = vim.re.match(word, time_regex)

                    if hour and minute then
                        output.time = setmetatable({
                            hour = tonumber(hour),
                            minute = tonumber(minute),
                            second = second and tonumber(second) or nil,
                        }, {
                            __tostring = function()
                                return word
                            end,
                        })

                        goto continue
                    end
                end

                do
                    local valid_months = {}

                    -- Check for month abbreviation
                    for i, month in ipairs(months) do
                        if vim.startswith(month, word:lower()) then
                            valid_months[month] = i
                        end
                    end

                    local count = vim.tbl_count(valid_months)
                    if count > 1 then
                        return "Ambiguous month name! Possible interpretations: "
                            .. table.concat(vim.tbl_keys(valid_months), ",")
                    elseif count == 1 then
                        local valid_month_name, valid_month_number = next(valid_months)

                        output.month = {
                            name = lib.title(valid_month_name),
                            number = valid_month_number,
                        }

                        goto continue
                    end
                end

                do
                    word = word:match("^([^,]+),?$")

                    local valid_weekdays = {}

                    -- Check for weekday abbreviation
                    for i, weekday in ipairs(weekdays) do
                        if vim.startswith(weekday, word:lower()) then
                            valid_weekdays[weekday] = i
                        end
                    end

                    local count = vim.tbl_count(valid_weekdays)
                    if count > 1 then
                        return "Ambiguous weekday name! Possible interpretations: "
                            .. table.concat(vim.tbl_keys(valid_weekdays), ",")
                    elseif count == 1 then
                        local valid_weekday_name, valid_weekday_number = next(valid_weekdays)

                        output.weekday = {
                            name = lib.title(valid_weekday_name),
                            number = valid_weekday_number,
                        }

                        goto continue
                    end
                end

                return "Unidentified string: `"
                    .. word
                    .. "` - make sure your locale and language are set correctly if you are using a language other than English!"
            end

            ::continue::
        end

        return module.private.tostringable_date(output)
    end,
}

module.private = {
    tostringable_date = function(date_table)
        return setmetatable(date_table, {
            __tostring = function()
                local function d(str)
                    return str and (tostring(str) .. " ") or ""
                end

                return vim.trim(
                    d(date_table.weekday and date_table.weekday.name)
                        .. d(date_table.day)
                        .. d(date_table.month and date_table.month.name)
                        .. d(date_table.year and string.format("%04d", date_table.year))
                        .. d(date_table.time and tostring(date_table.time))
                        .. d(date_table.timezone)
                )
            end,
        })
    end,
}

module.load = function()
    modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybinds(module.name, { "insert-date", "insert-date-insert-mode" })
    end)
end

module.on_event = function(event)
    if
        event.split_type[2] ~= "core.tempus.insert-date"
        and event.split_type[2] ~= "core.tempus.insert-date-insert-mode"
    then
        return
    end

    local function callback(input)
        if input == "" or not input then
            return
        end

        local output

        if type(input) == "table" then
            output = tostring(module.public.to_date(input))
        else
            output = module.public.parse_date(input)

            if type(output) == "string" then
                utils.notify(output, vim.log.levels.ERROR)

                vim.ui.input({
                    prompt = "Date: ",
                    default = input,
                }, callback)

                return
            end

            output = tostring(output)
        end

        vim.api.nvim_put({ "{@ " .. output .. "}" }, "c", false, true)

        if vim.endswith(event.split_type[2], "insert-mode") then
            vim.cmd.startinsert()
        end
    end

    if modules.is_module_loaded("core.ui.calendar") then
        vim.cmd.stopinsert()
        modules.get_module("core.ui.calendar").select_date({ callback = vim.schedule_wrap(callback) })
    else
        vim.ui.input({
            prompt = "Date: ",
        }, callback)
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".insert-date"] = true,
        [module.name .. ".insert-date-insert-mode"] = true,
    },
}

return module
