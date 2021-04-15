--[[
--	HELPER FUNCTIONS FOR NEORG
--	This file contains some simple helper function improve quality of life
--]]


-- Yoinked straight from stackoverflow, don't judge
function string.split(inputstr, sep)

        if sep == nil then
                sep = "%s"
        end

        local ret = {}

        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		if str:len() > 0 then
			table.insert(ret, str)
		end
        end

        return ret
end

function copy(obj, seen)
	if type(obj) ~= 'table' then
		return obj
	end
	if seen and seen[obj] then
		return seen[obj]
	end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do
		res[copy(k, s)] = copy(v, s)
	end
	return res
end
