-- FaceTargetConfig.lua
-- 顔ターゲットの種類、HP、報酬などの設定

local FaceTargetConfig = {}

-- 顔ターゲットの種類定義
FaceTargetConfig.TargetTypes = {
	NORMAL = {
		maxHP = 25, -- 25回に変更
		rewardAmount = 500,
		coinCount = 2,
		despawnSeconds = 600, -- 10分
		displayName = "ビッグフェイス",
		color = Color3.fromRGB(255, 200, 100),
		scale = 1.2
	},
	RARE = {
		maxHP = 25, -- 25回に変更
		rewardAmount = 1500,
		coinCount = 2,
		despawnSeconds = 600, -- 10分
		displayName = "レアフェイス",
		color = Color3.fromRGB(255, 100, 255),
		scale = 1.5
	}
}

-- スポーン設定
FaceTargetConfig.SpawnHeight = 100
FaceTargetConfig.SpawnRadius = 50 -- プレイヤーからの距離
FaceTargetConfig.RewardShareRadius = 35 -- 報酬を共有する範囲 (スタッド)

-- 属性名
FaceTargetConfig.AttrHP = "FaceHP"
FaceTargetConfig.AttrMaxHP = "FaceMaxHP"
FaceTargetConfig.AttrTargetId = "FaceTargetId"

return FaceTargetConfig
