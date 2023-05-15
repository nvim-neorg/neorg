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

local module = neorg.modules.create("core.tempus")

-- NOTE: Maybe encapsulate whole date parser in a single PEG grammar?
local time_regex = vim.re.compile([[{%d%d?} ":" {%d%d} ("." {%d%d?})?]])

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

module.public = {
    --- Converts a parsed date with `parse_date` to a lua date.
    ---@param parsed_date Date #The date to convert
    ---@return osdate #A Lua date
    to_lua_date = function(parsed_date)
        return {
            day = parsed_date.day,
            month = parsed_date.month and parsed_date.month.number or nil,
            year = parsed_date.year,
            hour = parsed_date.time and parsed_date.time.hour,
            min = parsed_date.time and parsed_date.time.minute,
            sec = parsed_date.time and parsed_date.time.second,
            wday = parsed_date.weekday and parsed_date.weekday.number,
            isdst = true,
        }
    end,

    --- Parses a date and returns a table representing the date
    ---@param input string #The input which should follow the date specification found in the Norg spec.
    ---@return Date|string #The data extracted from the input or an error message
    parse_date = function(input)
        local weekdays = {}
        for i = 1, 7 do
            table.insert(weekdays, os.date("%A", os.time({ year = 2000, month = 5, day = i })):lower())
        end

        local months = {}
        for i = 1, 12 do
            table.insert(months, os.date("%B", os.time({ year = 2000, month = i, day = 1 })):lower())
        end

        local output = {}

        for word in vim.gsplit(input, "%s+") do
            if word:len() == 0 then
                goto continue
            end

            if word:match("^-?%d%d%d%d+$") then
                output.year = tonumber(word)
            elseif word:match("^%d+%w+,?$") then
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
                            name = neorg.lib.title(valid_month_name),
                            number = valid_month_number,
                        }

                        goto continue
                    end
                end

                do
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
                            name = neorg.lib.title(valid_weekday_name),
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

        return setmetatable(output, {
            __tostring = function()
                local function d(str)
                    return str and (tostring(str) .. " ") or ""
                end

                return d(output.weekday and output.weekday.name)
                    .. d(output.day)
                    .. d(output.month and output.month.name)
                    .. d(output.year and string.format("%04d", output.year))
                    .. d(output.time and tostring(output.time))
                    .. (output.timezone or "")
            end,
        })
    end,
}

return module
