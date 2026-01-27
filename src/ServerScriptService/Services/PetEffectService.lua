--// PetEffectService.lua
--// ペット効果の唯一の入り口API
--// 他サービス（CanService等）はこのモジュールのみを参照すること

local ServerScriptService = game:GetService("ServerScriptService")

local PetEffectService = {}

-- EffectState（内部実装として隠蔽）
local EffectState = nil
local function getEffectState()
	if not EffectState then
		EffectState = require(ServerScriptService.Services.EffectState)
	end
	return EffectState
end

----------------------------------------------------------------
-- public: プレイヤーのペットボーナス倍率を取得
-- @param player Player
-- @return number (例: 1.0, 1.25, 1.50)
----------------------------------------------------------------
function PetEffectService.getPetBonusMult(player)
	if not player then
		return 1.0
	end
	
	local ES = getEffectState()
	if ES then
		local state = ES.Get(player)
		if state and state.PetBonusMult then
			return state.PetBonusMult
		end
	end
	
	return 1.0
end

----------------------------------------------------------------
-- public: プレイヤーの装備ペット一覧を取得
-- @param player Player
-- @return table (例: {"Pet_Starter", "Pet_Lucky"})
----------------------------------------------------------------
function PetEffectService.getEquippedPets(player)
	if not player then
		return {}
	end
	
	local ES = getEffectState()
	if ES then
		local state = ES.Get(player)
		if state and state.PetsEquipped then
			return state.PetsEquipped
		end
	end
	
	return {}
end

----------------------------------------------------------------
-- public: プレイヤーの装備ペットを設定（唯一の窓口）
-- @param player Player
-- @param petIdsTable table (例: {"Pet_Starter", "Pet_Lucky"})
----------------------------------------------------------------
function PetEffectService.setEquippedPets(player, petIdsTable)
	if not player then return end
	
	local ES = getEffectState()
	if ES then
		ES.SetPets(player, petIdsTable or {})
		ES.Recalc(player)
	end
end

----------------------------------------------------------------
-- 初期化（将来の拡張用）
----------------------------------------------------------------
function PetEffectService.Init()
	print("[PetEffectService] Init")
	-- EffectState の初期化は PetService.Init() 内で呼ばれている
end

return PetEffectService
