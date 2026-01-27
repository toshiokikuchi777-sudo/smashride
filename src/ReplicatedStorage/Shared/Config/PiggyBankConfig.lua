-- PiggyBankConfig.lua
-- 豚の貯金箱の種類、HP、報酬などの設定

local PiggyBankConfig = {}

-- ターゲットの種類定義
PiggyBankConfig.TargetTypes = {
	PIGGY = {
		maxHP = 20,
		rewardAmount = 800,
		coinCount = 3,
		despawnSeconds = 600,
		displayName = "豚の貯金箱",
		color = Color3.fromRGB(255, 150, 150),
		scale = 8.0 -- ペットのモデルなので大きくする
	}
}

-- 属性名 (互換性のためにFaceTargetと共通)
PiggyBankConfig.AttrHP = "FaceHP"
PiggyBankConfig.AttrMaxHP = "FaceMaxHP"
PiggyBankConfig.AttrTargetId = "FaceTargetId"

return PiggyBankConfig
