--// EffectState.lua
--// サーバー側：プレイヤー別の効果状態を管理（単一ソース）

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local EffectMath = require(ReplicatedStorage.Shared.Math.EffectMath)

local EffectState = {}

-- プレイヤー別の状態保持
local playerStates = {}

----------------------------------------------------------------
-- 内部：新しいプレイヤー状態を作成
----------------------------------------------------------------
local function createState()
	return {
		PetBonusMult = 1.0,    -- 例: 1.25 = +25%
		PetsEquipped = {},     -- 最大3匹の petId 配列
		OwnedPets = {},        -- 所持している全ペット配列
	}
end

----------------------------------------------------------------
-- public: プレイヤーの状態を取得
----------------------------------------------------------------
function EffectState.Get(player)
	if not playerStates[player] then
		playerStates[player] = createState()
	end
	return playerStates[player]
end

----------------------------------------------------------------
-- public: 装備ペットを設定（最大3匹）
----------------------------------------------------------------
function EffectState.SetPets(player, petIdsTable)
	local state = EffectState.Get(player)
	
	-- 最大3匹に制限
	local pets = {}
	for i = 1, math.min(#petIdsTable, 3) do
		table.insert(pets, petIdsTable[i])
	end
	
	state.PetsEquipped = pets
	print("[EffectState] SetPets for", player.Name, ":", table.concat(pets, ", "))
	
	-- Mark Dirty (via DataService if available) -- Lazy require inside if needed or just assume PetService handles it? 
	-- Actually EffectState is lower level. Let's make PetService handle the dirty mark for pets, 
	-- but EffectState is where the data actually changes.
	-- Let's simply fix the duplicate line first.
end

----------------------------------------------------------------
-- public: 所持ペットを設定 (LoadData用)
----------------------------------------------------------------
function EffectState.SetOwnedPets(player, petsTable)
	local state = EffectState.Get(player)
	state.OwnedPets = petsTable or {}
	print("[EffectState] SetOwnedPets for", player.Name)
end

----------------------------------------------------------------
-- public: データを一括適用 (DataServiceから呼ぶ)
----------------------------------------------------------------
function EffectState.InitData(player, savedData)
	local state = EffectState.Get(player)
	if savedData.ownedPets then
		state.OwnedPets = savedData.ownedPets
	end
	if savedData.equippedPets then
		state.PetsEquipped = savedData.equippedPets
	end
	-- 倍率再計算
	EffectState.Recalc(player)
end

----------------------------------------------------------------
-- public: ボーナス倍率を再計算
----------------------------------------------------------------
function EffectState.Recalc(player)
	local state = EffectState.Get(player)
	
	-- 装備中のペットのBonusMultリストを作成
	local petsInfo = {}
	for _, petId in ipairs(state.PetsEquipped) do
		table.insert(petsInfo, { BonusMult = PetConfig.GetBonus(petId) })
	end
	
	-- 計算を EffectMath に委譲 (policy="add" = 1 + sum)
	state.PetBonusMult = EffectMath.CalcPetBonusMult(petsInfo, "add")
	
	print("[EffectState] Recalc for", player.Name, "-> PetBonusMult:", state.PetBonusMult)
	
	return state.PetBonusMult
end

----------------------------------------------------------------
-- public: 同期用ペイロード生成（指示書 2/2）
----------------------------------------------------------------
function EffectState.BuildPayload(playerData, hammerMult, petBonusMult)
	local hm = hammerMult or 1
	local pm = petBonusMult or 1
	return {
		rev = playerData.effectRev or 0,
		hammerMult = hm,
		petBonusMult = pm,
		totalMult = hm * pm,
	}
end

----------------------------------------------------------------
-- public: プレイヤー退出時にクリーンアップ
----------------------------------------------------------------
function EffectState.Cleanup(player)
	playerStates[player] = nil
	print("[EffectState] Cleanup for", player.Name)
end

----------------------------------------------------------------
-- 初期化
----------------------------------------------------------------
function EffectState.Init()
	print("[EffectState] Init")
	
	local Players = game:GetService("Players")
	
	Players.PlayerRemoving:Connect(function(player)
		EffectState.Cleanup(player)
	end)
end

return EffectState
