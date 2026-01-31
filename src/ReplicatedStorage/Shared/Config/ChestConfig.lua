-- ReplicatedStorage/Shared/Config/ChestConfig.lua
-- 宝箱の設定

local ChestConfig = {}

ChestConfig.SpawnHeight = 100  -- 降ってくる高さ
ChestConfig.ClaimDistance = 15
ChestConfig.ClaimSpawnDelay = 1.0
ChestConfig.nearbyRadius = 25  -- 参加賞の範囲

ChestConfig.ChestTypes = {
	RED = {
		name = "Red Chest",
		displayName = "赤い宝箱",
		rewardAmount = 10,
		claimerReward = 8,
		nearbyReward = 2,
		color = Color3.fromRGB(255, 50, 50),
		despawnSeconds = 60,
	},
	BLUE = {
		name = "Blue Chest",
		displayName = "青い宝箱",
		rewardAmount = 25,
		claimerReward = 20,
		nearbyReward = 5,
		color = Color3.fromRGB(50, 50, 255),
		despawnSeconds = 60,
	},
	GREEN = {
		name = "Green Chest",
		displayName = "緑の宝箱",
		rewardAmount = 50,
		claimerReward = 40,
		nearbyReward = 10,
		color = Color3.fromRGB(50, 255, 50),
		despawnSeconds = 60,
	},
	GOLD = {
		name = "Gold Chest",
		displayName = "黄金の宝箱",
		rewardAmount = 100,
		claimerReward = 80,
		nearbyReward = 20,
		color = Color3.fromRGB(255, 215, 0),
		despawnSeconds = 60,
	}
}

-- ランダムな宝箱タイプを選択
function ChestConfig.SelectRandomChestType()
	local roll = math.random(1, 100)
	if roll <= 5 then return "GOLD"
	elseif roll <= 20 then return "GREEN"
	elseif roll <= 50 then return "BLUE"
	else return "RED"
	end
end

-- ランダムなスポーン位置を取得
function ChestConfig.GetRandomSpawnPosition()
	-- MapSettingsがあればそこから取得
	local mapSettings = workspace:FindFirstChild("MapSettings")
	local spawnPoints = mapSettings and mapSettings:FindFirstChild("SpawnPoints")
	local chestPoints = spawnPoints and spawnPoints:FindFirstChild("Chests")
	
	if chestPoints then
		local children = chestPoints:GetChildren()
		if #children > 0 then
			return children[math.random(1, #children)].Position
		end
	end
	
	-- フォールバック: 中央付近
	return Vector3.new(math.random(-50, 50), 10, math.random(-50, 50))
end

-- 指定位置付近のスポーン位置を取得
function ChestConfig.GetSpawnPositionNear(pos, radius)
	local angle = math.rad(math.random(0, 360))
	local dist = math.random(0, radius)
	-- 高さは少し高めに設定して降ってくる演出にする
	return pos + Vector3.new(math.cos(angle) * dist, ChestConfig.SpawnHeight, math.sin(angle) * dist)
end

return ChestConfig
