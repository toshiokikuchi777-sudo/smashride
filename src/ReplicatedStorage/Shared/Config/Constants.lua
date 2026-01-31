-- ReplicatedStorage/Shared/Config/Constants.lua
local C = {}

-- イベント名
C.Events = {
	GachaStarted = "GachaStarted",
	GachaCompleted = "GachaCompleted",
	CanSmashed = "CanSmashed",
	TotalScoreUpdated = "TotalScoreUpdated",
	PetEquipped = "PetEquipped",
	PetUnequipped = "PetUnequipped",
	HammerEquipped = "HammerEquipped",
	StageUnlocked = "StageUnlocked",
	ChestIdUpdated = "ChestIdUpdated",
	ChestEventStarted = "ChestEventStarted",
	ChestEventEnded = "ChestEventEnded",
	FaceTargetSpawned = "FaceTargetSpawned",
	FaceTargetDamaged = "FaceTargetDamaged",
	FaceTargetDespawned = "FaceTargetDespawned",
	GrindStarted = "GrindStarted",
	GrindEnded = "GrindEnded",
	SkateboardGrindJump = "SkateboardGrindJump",
	ScoreChanged = "ScoreChanged",
	CrushCanVisual = "CrushCanVisual",
	EffectStateSync = "EffectStateSync",
	RequestGacha = "RequestGacha",
	StageSync = "StageSync",
	ToggleSkateboard = "ToggleSkateboard",
	UnlockStateSync = "UnlockStateSync",
	ChestSpawned = "ChestSpawned",
	RewardNotification = "RewardNotification",
	RequestSpawn = "RequestSpawn",
	LeaderboardSync = "LeaderboardSync",
	ScrapChanged = "ScrapChanged",
	ShockwaveVFX = "ShockwaveVFX",
	GachaResult = "GachaResult",
	SkateboardStateSync = "SkateboardStateSync",
	ChestDespawned = "ChestDespawned",
	CansSmashed = "CansSmashed",
	MultiplierVFX = "MultiplierVFX",
	ChestClaimed = "ChestClaimed",
	ChestClaimRequest = "ChestClaimRequest",
	ClaimFeedbackReward = "ClaimFeedbackReward",
	EquipHammerRequest = "EquipHammerRequest",
	EventStateSync = "EventStateSync",
	FaceTargetDestroyed = "FaceTargetDestroyed",
	FaceTargetExpiring = "FaceTargetExpiring",
	FaceTargetHit = "FaceTargetHit",
	MoneyCollected = "MoneyCollected",
	PetInventorySync = "PetInventorySync",
	RequestEquipPet = "RequestEquipPet",
	StageUp = "StageUp",
	CanLocked = "CanLocked",
	CanCrushed = "CanCrushed",
	CanCrushResult = "CanCrushResult",
	SetEquippedHammer = "SetEquippedHammer",
	RequestScoreSync = "RequestScoreSync",
}

-- フォルダ名
C.RemotesFolderName = "Remotes"

-- 関数名
C.Functions = {
	LoadData = "LoadData",
	GetEquippedPets = "GetEquippedPets",
	GetEquippedHammer = "GetEquippedHammer",
	PurchaseSkateboard = "PurchaseSkateboard",
	GetPlayerHammers = "GetPlayerHammers",
	GetPlayerSkateboards = "GetPlayerSkateboards",
	EquipHammer = "EquipHammer",
	EquipSkateboard = "EquipSkateboard",
	RequestLeaderboard = "RequestLeaderboard",
	PurchaseHammer = "PurchaseHammer",
	RequestPetInventory = "RequestPetInventory",
}

-- アトリビュート名
C.Attr = {
	PetBonusMult = "PetBonusMult",
	HammerMult = "HammerMult",
	IsGrinding = "IsGrinding",
}

-- タグ名
C.Tags = {
	Can = "CAN",
	Breakable = "BREAKABLE",
	GrindRail = "GRIND_RAIL",
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