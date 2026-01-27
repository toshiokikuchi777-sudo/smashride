--// ServerScriptService/Services/GachaService.lua
--// ガチャシステムのサーバー側処理

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GachaService = {}

-- Lazy loaders
local DataService = nil
local function getDataService()
	if not DataService then
		DataService = require(ServerScriptService.Services.DataService)
	end
	return DataService
end

local PetService = nil
local function getPetService()
	if not PetService then
		PetService = require(ServerScriptService.Services.PetService)
	end
	return PetService
end

local CanService = nil
local function getCanService()
	if not CanService then
		CanService = require(ServerScriptService.Services.CanService)
	end
	return CanService
end

local UnlockService = nil
local function getUnlockService()
	if not UnlockService then
		UnlockService = require(ServerScriptService.Services.UnlockService)
	end
	return UnlockService
end

-- PetConfigから設定を取得
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local GACHA_COST = PetConfig.GachaCost
local GACHA_POOL = PetConfig.GachaPool
local totalWeight = PetConfig.GetTotalWeight()

----------------------------------------------------------------
-- Gacha Logic
----------------------------------------------------------------
local function rollGacha(tier)
	local tierData = PetConfig.Tiers[tier or "BASIC"] or PetConfig.Tiers.BASIC
	local pool = tierData.pool
	local totalWeight = PetConfig.GetTierTotalWeight(tier)
	
	local roll = math.random(1, totalWeight)
	local cumulative = 0
	for _, item in ipairs(pool) do
		cumulative = cumulative + item.weight
		if roll <= cumulative then
			return item.id
		end
	end
	return pool[1].id -- fallback
end

local function playerOwns(player, petId)
	local DS = getDataService()
	local data = DS.Get(player)
	if not data or not data.ownedPets then return false end
	for _, id in ipairs(data.ownedPets) do
		if id == petId then return true end
	end
	return false
end

local function addPetToPlayer(player, petId)
	local DS = getDataService()
	local data = DS.Get(player)
	if not data then return end
	if not data.ownedPets then data.ownedPets = {} end
	table.insert(data.ownedPets, petId)
	DS.MarkDirty(player)
end

----------------------------------------------------------------
-- Remote Setup
----------------------------------------------------------------
local Net = require(ReplicatedStorage.Shared.Net)

local function setupRemotes()
	local RequestGacha = Net.E("RequestGacha")
	local GachaResult = Net.E("GachaResult")
	local PetInventorySync = Net.E("PetInventorySync")
	
	-- Gacha Handler
	RequestGacha.OnServerEvent:Connect(function(player, tier)
		tier = tostring(tier or "BASIC"):upper()
		print("[GachaService] Gacha request from:", player.Name, "tier:", tier)
		
		local DS = getDataService()
		local data = DS.Get(player)
		
		if not data then
			print("[GachaService] ERROR: No data for player")
			GachaResult:FireClient(player, { ok = false, reason = "NO_DATA" })
			return
		end

		-- [指示書 7/8] ティア解放判定
		local US = getUnlockService()
		if US and not US.CanUseGachaTier(tier, data) then
			print("[GachaService] TIER_LOCKED:", tier, "for", player.Name)
			GachaResult:FireClient(player, { ok = false, reason = "TIER_LOCKED" })
			return
		end

		local tierData = PetConfig.Tiers[tier] or PetConfig.Tiers.BASIC
		local cost = tierData.cost
		local total = data.total or 0
		print("[GachaService] Player total:", total, "Cost:", cost)
		
		if total < cost then
			print("[GachaService] NOT_ENOUGH_SCRAP:", total, "<", cost)
			GachaResult:FireClient(player, { 
				ok = false, 
				reason = "NOT_ENOUGH_SCRAP",
				total = total,
				cost = cost
			})
			return
		end
		
		-- Deduct cost
		data.total = total - cost
		
		-- Roll
		local petId = rollGacha(tier)
		
		-- [CHANGED] Allow duplicates (User Request: Equip 2 if own 2)
		local isNew = not playerOwns(player, petId)
		addPetToPlayer(player, petId)
		
		-- 最強ペットを自動装備
		local PS = getPetService()
		if PS then
			PS.AutoEquipBest(player)
		end
		
		-- [FIX] スコア変更をサーバー側CanServiceに同期
		local cs = getCanService()
		if cs and cs.SetTotalScore then
			cs.SetTotalScore(player, data.total, "-" .. cost .. " (GACHA " .. tier .. ")")
		end
		
		DS.MarkDirty(player)
		
		print("[GachaService] Player", player.Name, "got:", petId, "(isNew:", isNew, ")")
		
		-- (AutoEquipBest will call SendSync internally)

		GachaResult:FireClient(player, {
			ok = true,
			petId = petId,
			isNew = isNew,
		})
	end)
	
	print("[GachaService] Remotes setup complete")
end

----------------------------------------------------------------
-- Init
----------------------------------------------------------------
function GachaService.Init()
	print("[GachaService] Init")
	setupRemotes()
end

return GachaService
