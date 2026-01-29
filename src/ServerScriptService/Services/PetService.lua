--// PetService.lua
--// ペットのスポーン/装備/管理（サーバー側）- Debug Version

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)

-- Models
local Models = ReplicatedStorage:FindFirstChild("Models")
local PetModels = Models and Models:FindFirstChild("Pets")

-- PetConfig (エイリアス対応)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

local PetService = {}

-- EffectState (Lazy Load)
local EffectState = nil
local function getEffectState()
	if not EffectState then
		EffectState = require(ServerScriptService.Services.EffectState)
	end
	return EffectState
end

-- DataService (Lazy Load)
local DataService = nil
local function getDataService()
	if not DataService then
		DataService = require(ServerScriptService.Services.DataService)
	end
	return DataService
end

-- Active Pet Instances [player] -> { [1]=Model, [2]=Model, [3]=Model }
local activePetModels = {} 

local PET_OFFSETS = {
	Vector3.new(0, 3, 3),     -- 1
	Vector3.new(-2, 3, 2),    -- 2
	Vector3.new(2, 3, 2),     -- 3
}

----------------------------------------------------------------
-- Internal: Spawn single pet instance
----------------------------------------------------------------
local function spawnSinglePet(player, petType, slotIndex)
	-- DYNAMIC ADDITION: Try to find models if missing (defensive)
	-- This handles cases where file system scan failed or loading order issues
	if not PetModels then
		local m = ReplicatedStorage:FindFirstChild("Models")
		if m then PetModels = m:FindFirstChild("Pets") end
	end

	if not PetModels then 
		warn("[PetService] CRITICAL: ReplicatedStorage.Models.Pets folder is missing!")
		return nil 
	end
	if not petType or petType == "" then return nil end
	
	-- エイリアス対応（Pet_Epic -> Pet_Flame など）
	local modelId = PetConfig.GetModelId(petType)
	local template = PetModels:FindFirstChild(modelId)
	if not template then
		warn("[PetService] Pet template not found:", modelId, "(original:", petType, ")")
		return nil
	end
	
	local character = player.Character
	if not character then return nil end
	
	local pet = template:Clone()
	pet.Name = petType .. "_" .. player.Name .. "_" .. slotIndex
	
	-- [STABILITY] Ensure PrimaryPart exists
	if not pet.PrimaryPart then
		local candidate = pet:FindFirstChild("Handle") or pet:FindFirstChild("Morph") or pet:FindFirstChild("Body") or pet:FindFirstChildWhichIsA("BasePart", true)
		if candidate then
			pet.PrimaryPart = candidate
			print("[PetService] Auto-set PrimaryPart for:", pet.Name, "to", candidate.Name)
		else
			warn("[PetService] No BasePart found in pet model:", pet.Name)
		end
	end

	-- [REINFORCEMENT] Add identifying attributes for robust client-side tracking
	pet:SetAttribute("OwnerUserId", player.UserId)
	pet:SetAttribute("SlotIndex", slotIndex)
	pet:SetAttribute("PetId", petType)
	
	-- [STABILITY] Weld all parts to PrimaryPart
	if pet.PrimaryPart then
		for _, part in ipairs(pet:GetDescendants()) do
			if part:IsA("BasePart") and part ~= pet.PrimaryPart then
				local weld = part:FindFirstChild("PetWeld")
				if not weld then
					weld = Instance.new("WeldConstraint")
					weld.Name = "PetWeld"
					weld.Part0 = pet.PrimaryPart
					weld.Part1 = part
					weld.Parent = part
				end
			end
		end
	end

	-- [CRITICAL] Disable all existing scripts inside the pet model
	for _, desc in ipairs(pet:GetDescendants()) do
		if desc:IsA("LuaSourceContainer") then 
			desc.Disabled = true 
		end
	end

	-- [PHYSICS] Prepare for client-side control
	if pet.PrimaryPart then
		for _, part in ipairs(pet:GetDescendants()) do
			if part:IsA("BasePart") then
				-- [FIX] Always start anchored to prevent falling through the world
				part.Anchored = true 
				part.CanCollide = false
			end
		end
		
		-- Set initial position
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local offset = PET_OFFSETS[slotIndex] or PET_OFFSETS[1]
			pet:PivotTo(rootPart.CFrame * CFrame.new(offset))
		end

		pet.Parent = workspace
		
		-- [CLEANUP] Network ownership is not needed for Anchored parts
		-- and the client will move them via PivotTo (LocalScript)
	else
		pet.Parent = workspace
	end

	return pet
end

----------------------------------------------------------------
-- Internal: Despawn Logic
----------------------------------------------------------------
local function despawnSlot(player, slotIndex)
	if activePetModels[player] and activePetModels[player][slotIndex] then
		local p = activePetModels[player][slotIndex]
		if p and p.Parent then p:Destroy() end
		activePetModels[player][slotIndex] = nil
	end
end

local function despawnAllPets(player)
	if activePetModels[player] then
		for i = 1, 3 do
			despawnSlot(player, i)
		end
	end
	activePetModels[player] = {}
end

----------------------------------------------------------------
-- Public API: Getters
----------------------------------------------------------------
function PetService.GetOwnedPets(player)
	local DS = getDataService()
	local data = DS.Get(player)
	local owned = (data and data.ownedPets) or { "Pet_Starter" }
	print("[PetService/DEBUG] GetOwnedPets for", player.Name, ":", #owned, "pets found.")
	return owned
end

function PetService.GetEquippedPets(player)
	local DS = getDataService()
	local data = DS.Get(player)
	-- Normalize to 3 slots
	local eq = (data and data.equippedPets) or { "", "", "" }
	for i = 1, 3 do
		if eq[i] == nil then eq[i] = "" end
	end
	return eq
end

----------------------------------------------------------------
-- Public API: SetEquippedPet
----------------------------------------------------------------
function PetService.SetEquippedPet(player, slotIndex, petIdOrEmpty, skipRecalc)
    print("[PetService/DEBUG] SetEquippedPet:", player.Name, "Slot:", slotIndex, "Pet:", petIdOrEmpty or "EMPTY")

	if slotIndex < 1 or slotIndex > 3 then
		warn("[PetService] Invalid slot:", slotIndex)
		return false
	end

	-- Check ownership (Count Check)
	if petIdOrEmpty and petIdOrEmpty ~= "" then
		local owned = PetService.GetOwnedPets(player)
		
		-- 1. Count how many the player owns
		local ownedCount = 0
		for _, id in ipairs(owned) do
			if id == petIdOrEmpty then
				ownedCount = ownedCount + 1
			end
		end
		
		if ownedCount == 0 then
			warn("[PetService] Player does not own:", petIdOrEmpty)
			return false
		end

		-- 2. Count how many are ALREADY equipped in OTHER slots
		local currentEquipped = PetService.GetEquippedPets(player)
		local equippedInOtherSlots = 0
		for i = 1, 3 do
			if i ~= slotIndex and currentEquipped[i] == petIdOrEmpty then
				equippedInOtherSlots = equippedInOtherSlots + 1
			end
		end

		-- 3. Validation
		if equippedInOtherSlots >= ownedCount then
			warn("[PetService] Not enough copies of:", petIdOrEmpty, "Owned:", ownedCount, "Equipped:", equippedInOtherSlots)
			return false
		end
	end

	-- Update Data
	local DS = getDataService()
	local data = DS.Get(player)
	if not data then return false end
	
	if not data.equippedPets then data.equippedPets = { "", "", "" } end
    for i=1,3 do if data.equippedPets[i]==nil then data.equippedPets[i]="" end end

	data.equippedPets[slotIndex] = petIdOrEmpty or ""
	
	-- Update Visuals (Models)
	despawnSlot(player, slotIndex)
    if petIdOrEmpty and petIdOrEmpty ~= "" then
        if not activePetModels[player] then activePetModels[player] = {} end
        
        local pModel = spawnSinglePet(player, petIdOrEmpty, slotIndex)
        if pModel then
            activePetModels[player][slotIndex] = pModel
        else
            -- Deferred spawn (Character logic)
            local conn
            conn = player.CharacterAdded:Connect(function()
                task.wait(0.3)
                local laterModel = spawnSinglePet(player, petIdOrEmpty, slotIndex)
                if laterModel then
                    activePetModels[player][slotIndex] = laterModel
                end
                conn:Disconnect()
            end)
        end
    end

	-- Update EffectState (Skip if bulk updating)
	if not skipRecalc then
		local ES = getEffectState()
		local currentEquipped = {}
		for i = 1, 3 do
			local pid = data.equippedPets[i]
			if pid and pid ~= "" then
				table.insert(currentEquipped, pid)
			end
		end
		ES.SetPets(player, currentEquipped)
		local petBonusMult = ES.Recalc(player)
		
		player:SetAttribute("EquippedPets", table.concat(currentEquipped, ","))

		-- [指示書 2/2] Revision付き同期
		data.effectRev = (data.effectRev or 0) + 1
		local hammerMult = player:GetAttribute("HammerMult") or 1.0
		local Net = require(ReplicatedStorage.Shared.Net)
		local payload = ES.BuildPayload(data, hammerMult, petBonusMult)
		Net.E("EffectStateSync"):FireClient(player, payload)
		print("[PetService/EffectSync] Sync sent rev:", data.effectRev, "pm:", petBonusMult)
	end

	-- Save
	DS.MarkDirty(player)
	return true
end

----------------------------------------------------------------
-- Public API: Bulk Equip
----------------------------------------------------------------
function PetService.EquipPets(player, petIdsTable) 
    for i = 1, 3 do
        local pid = petIdsTable[i] or ""
        PetService.SetEquippedPet(player, i, pid, true) -- skipRecalc = true
    end
	
	-- Perform single update at the end
	local currentEquipped = {}
	for i = 1, 3 do
		local pid = petIdsTable[i]
		if pid and pid ~= "" then
			table.insert(currentEquipped, pid)
		end
	end
	
	local ES = getEffectState()
	ES.SetPets(player, currentEquipped)
	local petBonusMult = ES.Recalc(player)
	
	player:SetAttribute("EquippedPets", table.concat(currentEquipped, ","))

	-- [指示書 2/2] 一括装備時の同期
	local DS = getDataService()
	local data = DS.Get(player)
	if data then
		data.effectRev = (data.effectRev or 0) + 1
		local hammerMult = player:GetAttribute("HammerMult") or 1.0
		local Net = require(ReplicatedStorage.Shared.Net)
		local payload = ES.BuildPayload(data, hammerMult, petBonusMult)
		Net.E("EffectStateSync"):FireClient(player, payload)
		print("[PetService/EffectSync] Bulk Sync sent rev:", data.effectRev, "pm:", petBonusMult)
	end
end

----------------------------------------------------------------
-- Public API: Auto Equip Best
----------------------------------------------------------------
function PetService.AutoEquipBest(player)
	print("[PetService/DEBUG] AutoEquipBest started for:", player.Name)
	
	local owned = PetService.GetOwnedPets(player)
	if #owned == 0 then 
		print("[PetService/DEBUG] No pets owned for", player.Name)
		return 
	end
	
	-- ペットを倍率順にソート (bonusPctが大きい順)
	local sortable = {}
	for _, petId in ipairs(owned) do
		local bonus = PetConfig.GetBonus(petId)
		table.insert(sortable, { id = petId, bonus = bonus })
		print("[PetService/DEBUG]   Pet candidate:", petId, "Bonus:", bonus)
	end
	
	table.sort(sortable, function(a, b)
		return a.bonus > b.bonus
	end)
	
	-- 上位3体を選出
	local newEquip = {}
	for i = 1, 3 do
		if sortable[i] then
			table.insert(newEquip, sortable[i].id)
		else
			table.insert(newEquip, "")
		end
	end
	
	print("[PetService/DEBUG]   Resulting Best 3:", table.concat(newEquip, ", "))
	
	-- 装備実行
	PetService.EquipPets(player, newEquip)
	
	-- クライアントへ同期
	PetService.SendSync(player)
	print("[PetService/DEBUG] AutoEquipBest finished for:", player.Name)
end

----------------------------------------------------------------
-- Public API: Send Sync
----------------------------------------------------------------
function PetService.SendSync(player)
    print("[PetService] Sending Sync to", player.Name)
    Net.E("PetInventorySync"):FireClient(player, {
        ownedPets = PetService.GetOwnedPets(player),
        equippedPets = PetService.GetEquippedPets(player)
    })
end

----------------------------------------------------------------
-- Remote Handlers (Setup)
----------------------------------------------------------------
local function setupRemotes()
    -- 1. Request Inventory
    Net.F("RequestPetInventory").OnServerInvoke = function(player)
        return {
            ownedPets = PetService.GetOwnedPets(player),
            equippedPets = PetService.GetEquippedPets(player)
        }
    end

    -- 2. Request Equip
    Net.On("RequestEquipPet", function(player, slotIndex, petIdOrEmpty)
        print("[PetService] Remote RequestEquipPet:", player.Name, slotIndex, petIdOrEmpty)
        local ok = PetService.SetEquippedPet(player, slotIndex, petIdOrEmpty)
        if ok then
            PetService.SendSync(player)
        else
            warn("[PetService] SetEquippedPet returned false")
        end
    end)
end

----------------------------------------------------------------
-- Init
----------------------------------------------------------------
function PetService.Init()
	print("[PetService] Init (Phase C: DEBUG)")
	
	setupRemotes()

    local ES = getEffectState()
	ES.Init()
    
	local function onPlayerReady(player)
        local DS = getDataService()
        local data = DS.Get(player)
        
        if data and data.equippedPets then
             PetService.EquipPets(player, data.equippedPets)
        else
             PetService.EquipPets(player, { "Pet_Starter" })
        end
    end

	-- [FIX] CharacterAddedでペットを再スポーン（視覚のみ、データはGameServerで設定済み）
	local function respawnPetsVisual(player)
		print("[PetService] respawnPetsVisual for:", player.Name)
		local equipped = PetService.GetEquippedPets(player)
		if not activePetModels[player] then activePetModels[player] = {} end
		
		for i = 1, 3 do
			local petType = equipped[i]
			if petType and petType ~= "" then
				-- 既存のモデルがあれば削除
				despawnSlot(player, i)
				-- 新しいモデルをスポーン
				local pModel = spawnSinglePet(player, petType, i)
				if pModel then
					activePetModels[player][i] = pModel
					print("[PetService] Respawned pet:", petType, "slot:", i)
				else
					warn("[PetService] Failed to respawn pet:", petType)
				end
			end
		end
		
		-- EquippedPets属性を更新（クライアント用）
		local currentEquipped = {}
		for i = 1, 3 do
			local pid = equipped[i]
			if pid and pid ~= "" then
				table.insert(currentEquipped, pid)
			end
		end
		player:SetAttribute("EquippedPets", table.concat(currentEquipped, ","))
	end
	
	local function connectCharacterAdded(player)
		player.CharacterAdded:Connect(function()
			print("[PetService] CharacterAdded for:", player.Name)
			task.wait(0.5) -- キャラクターが完全に読み込まれるのを待つ
			respawnPetsVisual(player)
		end)
	end
	
	-- 既存のプレイヤーに接続
	for _, player in ipairs(Players:GetPlayers()) do
		connectCharacterAdded(player)
		-- 既にキャラクターがいれば再スポーン
		if player.Character then
			task.spawn(function()
				task.wait(0.5)
				respawnPetsVisual(player)
			end)
		end
	end
	
	-- 新規プレイヤー
	Players.PlayerAdded:Connect(function(player)
		connectCharacterAdded(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		despawnAllPets(player)
	end)
end

return PetService
