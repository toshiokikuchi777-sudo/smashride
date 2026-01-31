-- ReplicatedStorage/Shared/Math/ScoreMath.lua
local ScoreMath = {}

local function n(x, default)
	local v = tonumber(x)
	if v == nil then return default or 0 end
	return v
end

-- baseScore: 缶の基礎スコア
-- totalMult: EffectMath.CalcTotalMult() の結果
function ScoreMath.CalcHitGain(baseScore, totalMult)
	local bs = n(baseScore, 0)
	local tm = n(totalMult, 1)
	if tm <= 0 then tm = 1 end
	local gain = math.floor(bs * tm)
	if gain < 0 then gain = 0 end
	return gain
end

function ScoreMath.CalcShockwaveGain(hitBaseScores, totalMult, mode)
	local tm = n(totalMult, 1)
	if tm <= 0 then tm = 1 end
	
	local total = 0
	if mode == "list" and typeof(hitBaseScores) == "table" then
		for _, bs in ipairs(hitBaseScores) do
			total = total + ScoreMath.CalcHitGain(bs, tm)
		end
	end
	return total
end

return ScoreMath
