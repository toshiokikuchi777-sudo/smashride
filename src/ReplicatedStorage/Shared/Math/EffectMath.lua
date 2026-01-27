-- ReplicatedStorage/Shared/Math/EffectMath.lua
local EffectMath = {}

-- 安全な数値化
local function n(x, default)
	local v = tonumber(x)
	if v == nil then return default or 0 end
	return v
end

-- pets: { {BonusMult=1.05}, {BonusMult=1.08} ... } など
-- policy: "mul"=掛け算合成 / "add"=加算合成(例:1+sum)
function EffectMath.CalcPetBonusMult(pets, policy)
	policy = policy or "mul"
	if not pets then return 1 end

	if policy == "add" then
		local sum = 0
		for _, p in ipairs(pets) do
			sum += n(p.BonusMult, 0)
		end
		return 1 + sum
	end

	-- default: mul
	local mult = 1
	for _, p in ipairs(pets) do
		local m = n(p.BonusMult, 1)
		if m <= 0 then m = 1 end
		mult *= m
	end
	return mult
end

-- hammerMult: ハンマー倍率(例 1.2, 2.0)
-- petBonusMult: ペット倍率(例 1.13, 1.52)
-- extra: 追加倍率（将来拡張用）
function EffectMath.CalcTotalMult(hammerMult, petBonusMult, extra)
	local hm = n(hammerMult, 1)
	local pm = n(petBonusMult, 1)
	local em = n(extra, 1)
	if hm <= 0 then hm = 1 end
	if pm <= 0 then pm = 1 end
	if em <= 0 then em = 1 end
	return hm * pm * em
end

return EffectMath
