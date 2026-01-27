-- ReplicatedStorage/Shared/Config/HammerShopConfig.lua
-- ハンマーショップの設定

local HammerShopConfig = {}

-- 通常の歩行速度
HammerShopConfig.NormalWalkSpeed = 16

-- ハンマーの種類と価格
HammerShopConfig.Hammers = {
	BASIC = {
		id = "BASIC",
		name = "Basic Hammer",
		displayName = "ベーシックハンマー",
		description = "なし",
		cost = 0,  -- 無料（初期装備）
		damageMultiplier = 1.0,
		modelId = "BasicHammer",
		imageAssetId = "rbxassetid://99473284780261"
	},
	SHOCKWAVE = {
		id = "SHOCKWAVE",
		name = "Shockwave Hammer",
		displayName = "ショックウェーブハンマー",
		description = "周りの缶を破壊",
		cost = 10,
		damageMultiplier = 1.5,
		modelId = "ShockwaveHammer",
		imageAssetId = "rbxassetid://123187642792098"
	},
	MULTI = {
		id = "MULTI",
		name = "Multi Hammer",
		displayName = "マルチハンマー",
		description = "ポイント倍増",
		cost = 25,
		damageMultiplier = 2.0,
		modelId = "MultiHammer",
		imageAssetId = "rbxassetid://104483286296373"
	},
	HYBRID = {
		id = "HYBRID",
		name = "Hybrid Hammer",
		displayName = "ハイブリッドハンマー",
		description = "周りの缶を破壊＆ポイント倍増",
		cost = 50,
		damageMultiplier = 3.0,
		modelId = "HybridHammer",
		imageAssetId = "rbxassetid://94773981591783"
	},
	MASTER = {
		id = "MASTER",
		name = "Master Hammer",
		displayName = "マスターハンマー",
		description = "周りの缶を破壊＆ポイント倍増＆全種破壊",
		cost = 100,
		damageMultiplier = 5.0,
		modelId = "MasterHammer",
		imageAssetId = "rbxassetid://83511820366201"
	},
	RAINBOW = {
		id = "RAINBOW",
		name = "Rainbow Hammer",
		displayName = "レインボーハンマー",
		description = "グループ参加 & いいね！報酬 (赤・青・緑破壊可能 / 小ショックウェーブ)",
		cost = 0,
		damageMultiplier = 3.0,
		modelId = "RainbowHammer",
		ability = "SMALL_SHOCKWAVE",
		isSpecial = true,
		imageAssetId = "rbxassetid://106362536838383"
	}
}

-- 表示順序
HammerShopConfig.Order = {
	"BASIC",
	"SHOCKWAVE",
	"MULTI",
	"HYBRID",
	"MASTER",
	"RAINBOW"
}

return HammerShopConfig
