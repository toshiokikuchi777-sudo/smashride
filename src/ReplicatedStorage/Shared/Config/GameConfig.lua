-- ReplicatedStorage/Shared/Config/GameConfig
print("[GameConfig] Module Loading...")
local Config = {}

-- ステージ進行条件（破壊数ベース）
Config.StageRequirements = {
	[1]  = { cansSmashedTotal = 0 },
	[2]  = { cansSmashedTotal = 25 },
	[3]  = { cansSmashedTotal = 80 },      -- 100 -> 80
	[4]  = { cansSmashedTotal = 300 },     -- 500 -> 300
	[5]  = { cansSmashedTotal = 1000 },    -- 2000 -> 1000
	[6]  = { cansSmashedTotal = 3000 },    -- 5000 -> 3000
	[7]  = { cansSmashedTotal = 10000 },   -- 12000 -> 10000
	[8]  = { cansSmashedTotal = 25000 },   -- 30000 -> 25000
	[9]  = { cansSmashedTotal = 60000 },   -- そのまま
	[10] = { cansSmashedTotal = 100000 },  -- そのまま
}

local function getReq(stage)
	local s = tonumber(stage) or 1
	local req = Config.StageRequirements[s]
	return req and (tonumber(req.cansSmashedTotal) or 0) or 0
end

function Config.GetStageFromSmashed(total)
	total = tonumber(total) or 0
	local stage = 1
	for s, req in pairs(Config.StageRequirements) do
		if total >= (tonumber(req.cansSmashedTotal) or 0) then
			if s > stage then stage = s end
		end
	end
	return stage
end

-- ✅ 精密バー用：prevReq / nextReq を返す
function Config.GetStageProgress(totalSmashed)
	totalSmashed = tonumber(totalSmashed) or 0

	local stage = Config.GetStageFromSmashed(totalSmashed)
	local prevReq = getReq(stage)

	local nextStage = stage + 1
	local nextReq = Config.StageRequirements[nextStage] and getReq(nextStage) or nil

	return stage, prevReq, nextReq
end

print("[GameConfig] StageRequirements defined")

Config.Cans = {
	Basic = {
		scrap = 1,
		jumpPower = 60,
	},
}

-- 缶の種類別設定（優しめVer.）
Config.CanTypes = {
	RED    = { point = 1 },
	BLUE   = { point = 2 },
	GREEN  = { point = 5 },
	PURPLE = { point = 10 },
	YELLOW = { point = 20 },
}

-- ハンマーの性能設定
Config.Hammers = {
	BASIC     = { ability = "NONE", scale = 1.0 },
	SHOCKWAVE = { ability = "SHOCKWAVE", radius = 30, cooldown = 8, scale = 1.0 },
	MULTI     = { ability = "MULTI", multipliers = { PURPLE=4.0, YELLOW=3.0, BLUE=2.5, GREEN=2.0, RED=1.5 }, scale = 1.0 },
	HYBRID    = { ability = "HYBRID", multipliers = { PURPLE=6.0, YELLOW=5.0, BLUE=4.0, GREEN=3.0, RED=2.0 }, radius = 30, cooldown = 8, scale = 1.0 }, 
	MASTER    = { ability = "MASTER", multipliers = { PURPLE=10.0, YELLOW=8.0, BLUE=6.0, GREEN=5.0, RED=5.0 }, radius = 40, cooldown = 5, scale = 1.0 },
	RAINBOW   = { ability = "SMALL_SHOCKWAVE", radius = 8, cooldown = 3, multipliers = { GREEN=2.0, BLUE=1.5, RED=1.2 }, scale = 1.1 },
}

-- ハンマー別の壊せる缶制限
Config.HammerCanLimit = {
	BASIC = 1,      -- RED
	SHOCKWAVE = 2,  -- RED, BLUE
	MULTI = 3,      -- RED, BLUE, GREEN
	HYBRID = 4,     -- RED, BLUE, GREEN, PURPLE
	MASTER = 5,     -- All colors
	RAINBOW = 3,    -- 赤・青・緑
}

Config.Unlocks = {
	SHOCKWAVE = { RED = 1 },
	MULTI     = { RED = 1 },
	HYBRID    = { RED = 1 },
}

Config.GamePassIds = {
	SHOCKWAVE = 0,
	MULTI     = 0,
	HYBRID    = 0,
}

Config.PvP = {
	Enabled = false,
}

-- ハンマー解放ルール (優しめVer.) - ハンマーショップ導入により無効化
--[[
Config.HammerUnlockRules = {
  BASIC = { default = true },
  SHOCKWAVE = { cansSmashedTotal = 100 },   -- 10 -> 100
  MULTI = { cansSmashedTotal = 1000 },      -- 50 -> 1000
  HYBRID = { cansSmashedTotal = 5000 },     -- 150 -> 5000
  MASTER = { cansSmashedTotal = 20000 },    -- 1000 -> 20000
}
--]]

-- ガチャティア解放ルール (優しめVer.)
Config.GachaTierRules = {
  BASIC  = { default = true },
  RARE   = { cansSmashedTotal = 150 },   -- 500 -> 150
  LEGEND = { cansSmashedTotal = 1000 },  -- 5000 -> 1000
}

-- ペットボーナスはPetConfig.luaに移行
-- 参照: ReplicatedStorage.Shared.Config.PetConfig

-- データリセット用キー
Config.TEST_RESET_KEY = "RESET_v14_NoInitialEquipment"

-- リーダーボードリセット用キー
Config.LEADERBOARD_VERSION = "v3"

return Config
