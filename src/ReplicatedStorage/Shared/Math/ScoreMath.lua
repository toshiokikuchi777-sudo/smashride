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

-- shockwaveHits: 範囲で割った缶の「baseScore合計」でも「個別配列」でも使えるように
-- mode="sum" なら shockwaveHits を合計値として扱う
-- mode="list" なら {10, 20, 5} のような配列として扱う
function ScoreMath.CalcShockwaveGain(shockwaveHits, totalMult, mode)
	mode = mode or "list"
	local tm = n(totalMult, 1)
	if tm <= 0 then tm = 1 end

	local sumBase = 0
	if mode == "sum" then
		sumBase = n(shockwaveHits, 0)
	else
		if shockwaveHits then
			for _, bs in ipairs(shockwaveHits) do
				sumBase += n(bs, 0)
			end
		end
	end

	local gain = math.floor(sumBase * tm)
	if gain < 0 then gain = 0 end
	return gain, sumBase
end

return ScoreMath
