-- ReplicatedStorage/Shared/UnlockText.lua
local UnlockText = {}

local function fmt(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return r:gsub("^,", "")
end

function UnlockText.Hammer(rule)
	if not rule or rule.default then
		return "最初から使用可能"
	end

	local parts = {}
	if rule.stage then
		table.insert(parts, ("ステージ %d 以上"):format(rule.stage))
	end
	if rule.cansSmashedTotal then
		table.insert(parts, ("Need %s Cans"):format(fmt(rule.cansSmashedTotal)))
	end

	if #parts == 0 then
		return "Unlocked"
	end
	return table.concat(parts, "\n")
end

return UnlockText
