-- ServerScriptService/Core/GameServer.server.lua

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServicesFolder      = ServerScriptService:WaitForChild("Services")

-- Services (Require Order: Data -> Core -> Gameplay)
-- "WaitForChild" is safe here because this script runs on server start
local DataService       = require(ServicesFolder:WaitForChild("DataService"))
local GachaService      = require(ServicesFolder:WaitForChild("GachaService"))
local SpawnerService    = require(ServicesFolder:WaitForChild("SpawnerService"))
local PetEffectService  = require(ServicesFolder:WaitForChild("PetEffectService"))
local PetService        = require(ServicesFolder:WaitForChild("PetService"))
local CanService        = require(ServicesFolder:WaitForChild("CanService"))
local EffectState       = require(ServicesFolder:WaitForChild("EffectState"))
local SkateboardService = require(ServicesFolder:WaitForChild("SkateboardService"))
local GrindService      = require(ServicesFolder:WaitForChild("GrindService"))
local SkateboardShopService = require(ServicesFolder:WaitForChild("SkateboardShopService"))
local HammerShopService = require(ServicesFolder:WaitForChild("HammerShopService"))
local SpawnService      = require(ServicesFolder:WaitForChild("SpawnService"))
local SurveyService     = require(ServicesFolder:WaitForChild("SurveyService"))
local ChestService      = require(ServicesFolder:WaitForChild("ChestService"))
local EventService      = require(ServicesFolder:WaitForChild("EventService"))
local FaceTargetService = require(ServicesFolder:WaitForChild("FaceTargetService"))
local PiggyBankService = require(ServicesFolder:WaitForChild("PiggyBankService"))
local PromotionService = require(ServicesFolder:WaitForChild("PromotionService"))
local MoneyDrop         = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MoneyDrop"))
local Net               = require(ReplicatedStorage.Shared.Net)

-- コイン取得イベントを事前に作成（クライアントがリスナーを登録できるようにする）
Net.E("MoneyCollected")

----------------------------------------------------------------
-- Initialize Services (Order Matters)
----------------------------------------------------------------
-- 1. Data & Base
DataService.Init()
MoneyDrop.Init()
GachaService.Init()
SpawnerService.Init()
PetEffectService.Init()
EffectState.Init()

-- 2. Gameplay Services
CanService.Init()
PetService.Init() -- [FIX] Init needed for Remotes!
SkateboardService.Init()
GrindService.Init()
SkateboardShopService.Init()
HammerShopService.Init()
SpawnService.Init()
SurveyService.Init()
ChestService.Init()
EventService.Init()
FaceTargetService.Init()
PiggyBankService.Init()
PromotionService.Init()

----------------------------------------------------------------
-- Central Player Flow
----------------------------------------------------------------
local function onPlayerAdded(player)
	print("[GameServer] Player joining:", player.Name)
	
	-- 1. Load Data
	local data = DataService.Load(player)
	
	-- 2. Apply Data to Services
	-- Pets (EffectState)
	if data.ownedPets then
		EffectState.SetOwnedPets(player, data.ownedPets)
	end
	
	-- Equipped (Ensuring Best Pets on Join)
	if data.ownedPets and #data.ownedPets > 0 then
		PetService.AutoEquipBest(player)
	elseif data.equippedPets then
		PetService.EquipPets(player, data.equippedPets)
	end
	
	-- Score (CanService)
	if data.total then
		CanService.SetTotalScore(player, data.total)
	end
	
	-- Promotion Rewards
	task.spawn(function()
		PromotionService.CheckCommunityReward(player)
	end)
	
	-- Hammer (自動装備 - BASICハンマーをゲーム開始時に装備)
	task.wait(0.5) -- サービスの初期化を待つ
	local HammerShopService = require(ServicesFolder:WaitForChild("HammerShopService"))
	local equippedHammer = data.equippedHammer or "BASIC"
	HammerShopService.EquipHammer(player, equippedHammer)
	
	print("[GameServer] Data applied for:", player.Name)
end

-- Connect PlayerAdded
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function() onPlayerAdded(p) end)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- 7. LeaderboardService
local LeaderboardService = require(ServicesFolder:WaitForChild("LeaderboardService"))
LeaderboardService.Init()

print("[GameServer] Init Complete! (Data Persistence Enabled)")
