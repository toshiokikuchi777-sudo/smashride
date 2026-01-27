-- ReplicatedStorage/Shared/Config/Constants.lua
-- 文字列キーの集中管理（指示書 2/4 準拠）

local C = {}

C.RemotesFolderName = "Remotes"

-- RemoteEvent 名
C.Events = {
	-- Score / Currency
	ScrapChanged = "ScrapChanged",
	ScoreChanged = "ScoreChanged",
	CansSmashed = "CansSmashed",        -- 累計破壊数の通知

	-- Cans / Hitting
	CanCrushed = "CanCrushed",
	CanCrushResult = "CanCrushResult",
	CrushCanVisual = "CrushCanVisual",

	-- Hammers
	SetEquippedHammer = "SetEquippedHammer",
	EquipHammerRequest = "EquipHammerRequest",
	HammerUnlockStatus = "HammerUnlockStatus",
	HammerAbilityResult = "HammerAbilityResult",

	-- Gacha
	RequestGacha = "RequestGacha",
	GachaResult = "GachaResult",
	RequestUnlockSync = "RequestUnlockSync",

	-- Pets
	RequestEquipPet = "RequestEquipPet",
	PetInventorySync = "PetInventorySync",

	-- VFX / Misc
	EffectStateSync = "EffectStateSync",
	UnlockStateSync = "UnlockStateSync",
	ShockwaveFired = "ShockwaveFired",
	ShockwaveVFX = "ShockwaveVFX",
	MultiplierVFX = "MultiplierVFX",

	-- Stage
	StageUp = "StageUp",
	StageSync = "StageSync",

	-- Leaderboard
	LeaderboardSync = "LeaderboardSync",

	-- Can Restrictions
	CanLocked = "CanLocked",

	-- Skateboard
	ToggleSkateboard = "ToggleSkateboard",
	SkateboardStateSync = "SkateboardStateSync",
	SkateboardGrindJump = "SkateboardGrindJump",

	-- Spawn
	RequestSpawn = "RequestSpawn",
	
	-- Chest Event
	ChestClaimRequest = "ChestClaimRequest",
	ChestSpawned = "ChestSpawned",
	ChestDespawned = "ChestDespawned",
	ChestClaimed = "ChestClaimed",
	EventStateSync = "EventStateSync",
	MoneyCollected = "MoneyCollected",

	-- Face Target Bonus
	FaceTargetSpawned = "FaceTargetSpawned",
	FaceTargetHit = "FaceTargetHit",
	FaceTargetDamaged = "FaceTargetDamaged",
	FaceTargetDestroyed = "FaceTargetDestroyed",
	FaceTargetExpiring = "FaceTargetExpiring",

	-- Promotions
	ClaimFeedbackReward = "ClaimFeedbackReward",
	RewardNotification = "RewardNotification",
}

-- RemoteFunctions
C.Functions = {
	-- Skateboard Shop
	PurchaseSkateboard = "PurchaseSkateboard",
	EquipSkateboard = "EquipSkateboard",
	GetPlayerSkateboards = "GetPlayerSkateboards",

	-- Hammer Shop
	PurchaseHammer = "PurchaseHammer",
	EquipHammer = "EquipHammer",
	GetPlayerHammers = "GetPlayerHammers",

	-- Existing functions
	RequestPetInventory = "RequestPetInventory",
	EquipPet = "EquipPet",
	UnequipPet = "UnequipPet",
	RequestLeaderboard = "RequestLeaderboard",
	RequestGacha = "RequestGacha",
	CheckGamePass = "CheckGamePass",
}

-- データキー（DataServiceで使用）
C.DataKey = {
	Scrap = "Scrap",
	TotalScore = "TotalScore",
	OwnedPets = "OwnedPets",
	EquippedPets = "EquippedPets",
	EquippedHammer = "EquippedHammer",
}

-- アトリビュート名
C.Attr = {
	PetBonusMult = "PetBonusMult",
	HammerMult = "HammerMult",
	IsGrinding = "IsGrinding",
}

-- タグ名
C.Tag = {
	Can = "CAN",
	Breakable = "BREAKABLE",
}

-- 缶の色インデックス（ハンマーの制限判定用）
C.CanColorIndex = {
	RED = 1,
	BLUE = 2,
	YELLOW = 5,
	GREEN = 3,
	PURPLE = 4,
}

return C