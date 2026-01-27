-- ChestConfig.lua
-- 宝箱の種類、報酬、参加賞範囲の設定

local ChestConfig = {}

-- 宝箱の種類定義
ChestConfig.ChestTypes = {
	RED = {
		weight = 60, -- 抽選重み(60%)
		claimerReward = 50, -- 先着報酬
		nearbyReward = 10, -- 参加賞
		nearbyRadius = 30, -- 参加賞範囲(studs)
		despawnSeconds = 60, -- 拾われない場合の消滅時間 (延長)
		vfxKey = "RED", -- 演出キー
		displayName = "赤の宝箱",
		color = Color3.fromRGB(255, 80, 80)
	},
	BLUE = {
		weight = 25,
		claimerReward = 120,
		nearbyReward = 20,
		nearbyRadius = 35,
		despawnSeconds = 80, -- 延長
		vfxKey = "BLUE",
		displayName = "青の宝箱",
		color = Color3.fromRGB(80, 150, 255)
	},
	GREEN = {
		weight = 12,
		claimerReward = 250,
		nearbyReward = 40,
		nearbyRadius = 40,
		despawnSeconds = 100, -- 延長
		vfxKey = "GREEN",
		displayName = "緑の宝箱",
		color = Color3.fromRGB(80, 255, 150)
	},
	GOLD = {
		weight = 3,
		claimerReward = 800,
		nearbyReward = 100,
		nearbyRadius = 50,
		despawnSeconds = 120, -- 延長
		vfxKey = "GOLD",
		displayName = "金の宝箱",
		color = Color3.fromRGB(255, 215, 0)
	}
}

-- 宝箱取得の距離制限(ハンマーのリーチ等に合わせて緩和)
ChestConfig.ClaimDistance = 30 -- studs (12から30に拡大)

-- 宝箱がスポーンしてから取得可能になるまでの猶予時間 (秒)
ChestConfig.ClaimSpawnDelay = 1.5 -- 降下演出に合わせて調整

-- 参加賞に先着プレイヤーを含めるか
ChestConfig.IncludeClaimerInNearby = false -- false推奨(先着がさらに得しないように)

-- 宝箱のスポーン高度(Y座標)
ChestConfig.SpawnHeight = 100 -- 空から降ってくる高さ

-- 宝箱のスポーン範囲(ワールド中心からの範囲)
ChestConfig.SpawnRange = {
	minX = -150,
	maxX = 150,
	minZ = -150,
	maxZ = 150
}

-- 重みから宝箱タイプを抽選する関数
function ChestConfig.SelectRandomChestType()
	local totalWeight = 0
	for _, chestData in pairs(ChestConfig.ChestTypes) do
		totalWeight = totalWeight + chestData.weight
	end
	
	local random = math.random() * totalWeight
	local currentWeight = 0
	
	for chestType, chestData in pairs(ChestConfig.ChestTypes) do
		currentWeight = currentWeight + chestData.weight
		if random <= currentWeight then
			return chestType
		end
	end
	
	return "RED" -- フォールバック
end

-- ランダムなスポーン位置を取得
function ChestConfig.GetRandomSpawnPosition()
	local x = math.random(ChestConfig.SpawnRange.minX, ChestConfig.SpawnRange.maxX)
	local z = math.random(ChestConfig.SpawnRange.minZ, ChestConfig.SpawnRange.maxZ)
	local y = ChestConfig.SpawnHeight
	
	return Vector3.new(x, y, z)
end

-- 特定の座標の周辺にスポーン位置を取得
function ChestConfig.GetSpawnPositionNear(centerPos, radius)
	local angle = math.rad(math.random(0, 360))
	local dist = math.random(10, radius or 50)
	local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
	
	return centerPos + offset + Vector3.new(0, ChestConfig.SpawnHeight, 0)
end

return ChestConfig
