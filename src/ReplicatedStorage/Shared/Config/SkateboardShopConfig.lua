-- ReplicatedStorage/Shared/Config/SkateboardShopConfig.lua
-- スケボーショップの設定

local SkateboardShopConfig = {}

-- スケボーの種類と能力
SkateboardShopConfig.Skateboards = {
	BASIC = {
		name = "Amber Black",
		displayName = "ブラック・アンバー",
		cost = 0,
		speedMultiplier = 1.0,
		jumpPowerBonus = 0,
		modelId = "Skateboard01",
		description = "ダークグレーに琥珀色の輝きを纏ったボード",
		imageAssetId = "rbxassetid://78360164531626"
	},
	SPEED = {
		name = "Royal Purple",
		displayName = "ロイヤル・パープル",
		cost = 10,
		speedMultiplier = 1.3,
		jumpPowerBonus = 0,
		modelId = "Skateboard02",
		description = "高貴な紫と赤の光を放つ高速ボード",
		imageAssetId = "rbxassetid://78145825813819"
	},
	JUMP = {
		name = "Crimson Red",
		displayName = "クリムゾン・レッド",
		cost = 25,
		speedMultiplier = 1.0,
		jumpPowerBonus = 30,
		modelId = "Skateboard03",
		description = "燃え盛る紅蓮のようなジャンプボード",
		imageAssetId = "rbxassetid://78906974744246"
	},
	BALANCED = {
		name = "Sunny Gold",
		displayName = "サニー・ゴールド",
		cost = 50,
		speedMultiplier = 1.2,
		jumpPowerBonus = 15,
		modelId = "Skateboard04",
		description = "太陽のように光り輝く黄金のボード",
		imageAssetId = "rbxassetid://93328325032325"
	},
	ULTIMATE = {
		name = "Neon Pink",
		displayName = "ネオン・ピンク",
		cost = 100,
		speedMultiplier = 1.6,
		jumpPowerBonus = 40,
		modelId = "Skateboard05",
		description = "鮮やかなネオンピンクを放つ究極のボード",
		imageAssetId = "rbxassetid://102133169697152"
	}
}

-- スケボーの順序（UI表示用）
SkateboardShopConfig.Order = {"BASIC", "SPEED", "JUMP", "BALANCED", "ULTIMATE"}

-- 基本速度設定（SkateboardConfigから移行）
SkateboardShopConfig.BaseSkateboardSpeed = 40

return SkateboardShopConfig
