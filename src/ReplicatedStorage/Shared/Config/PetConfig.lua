--// ReplicatedStorage/Shared/Config/PetConfig.lua
--// ペットの単一真実源（Single Source of Truth）
--// 全ペットの定義、ボーナス、ガチャプールを一元管理

local PetConfig = {}

----------------------------------------------------------------
-- 全ペット定義
-- key = petId, value = { rarity, bonusPct, displayName, aliasOf? }
----------------------------------------------------------------
PetConfig.All = {
	-- === 新ペットID（11種類） ===
	-- コモン
	Pet_Starter = { rarity = "Common",    bonusPct = 0.05, displayName = "スターター" },
	Pet_Lucky   = { rarity = "Common",    bonusPct = 0.10, displayName = "ラッキー" },
	-- アンコモン
	Pet_Pink    = { rarity = "Uncommon",  bonusPct = 0.15, displayName = "ピンク" },
	Pet_Purple  = { rarity = "Uncommon",  bonusPct = 0.20, displayName = "パープル" },
	Pet_Shadow  = { rarity = "Uncommon",  bonusPct = 0.25, displayName = "シャドウ" },
	-- レア
	Pet_Golden  = { rarity = "Rare",      bonusPct = 0.40, displayName = "ゴールデン" },
	Pet_Crystal = { rarity = "Rare",      bonusPct = 0.60, displayName = "クリスタル" },
	-- エピック
	Pet_Flame   = { rarity = "Epic",      bonusPct = 1.00, displayName = "フレイム" },
	Pet_Thunder = { rarity = "Epic",      bonusPct = 1.50, displayName = "サンダー" },
	-- レジェンダリー
	Pet_Rainbow = { rarity = "Legendary", bonusPct = 2.00, displayName = "レインボー" },
	Pet_Cosmic  = { rarity = "Legendary", bonusPct = 3.00, displayName = "コズミック" },

	-- === 後方互換性のための旧ID（エイリアス） ===
	Pet_Epic = { rarity = "Epic", bonusPct = 2.00, displayName = "エピック", aliasOf = "Pet_Flame" },
	Pet_Rare = { rarity = "Rare", bonusPct = 0.80, displayName = "レア",     aliasOf = "Pet_Golden" },
}

----------------------------------------------------------------
-- ガチャ設定 (優しめVer.)
----------------------------------------------------------------
PetConfig.Tiers = {
  BASIC = {
    cost = 1000, -- 50 -> 1000
    pool = {
      { id = "Pet_Starter", weight = 30 },
      { id = "Pet_Lucky",   weight = 30 },
      { id = "Pet_Pink",    weight = 10 },
      { id = "Pet_Purple",  weight = 10 },
      { id = "Pet_Shadow",  weight = 10 },
      { id = "Pet_Golden",  weight = 5 },
      { id = "Pet_Crystal", weight = 5 },
    }
  },
  RARE = {
    cost = 5000, -- 50000 -> 5000
    pool = {
      { id = "Pet_Pink",    weight = 20 },
      { id = "Pet_Purple",  weight = 20 },
      { id = "Pet_Shadow",  weight = 20 },
      { id = "Pet_Golden",  weight = 15 },
      { id = "Pet_Crystal", weight = 15 },
      { id = "Pet_Flame",   weight = 5 },
      { id = "Pet_Thunder", weight = 5 },
    }
  },
  LEGEND = {
    cost = 100000, -- 1000000 -> 100000
    pool = {
      { id = "Pet_Golden",  weight = 20 },
      { id = "Pet_Crystal", weight = 20 },
      { id = "Pet_Flame",   weight = 25 },
      { id = "Pet_Thunder", weight = 25 },
      { id = "Pet_Rainbow", weight = 5 },
      { id = "Pet_Cosmic",  weight = 5 },
    }
  }
}

-- 後方互換性用
PetConfig.GachaPool = PetConfig.Tiers.BASIC.pool
PetConfig.GachaCost = PetConfig.Tiers.BASIC.cost

----------------------------------------------------------------
-- ユーティリティ関数
----------------------------------------------------------------

-- 特定ティアの合計重みを計算
function PetConfig.GetTierTotalWeight(tier)
  local tierData = PetConfig.Tiers[tier or "BASIC"] or PetConfig.Tiers.BASIC
  local total = 0
  for _, item in ipairs(tierData.pool) do
    total = total + item.weight
  end
  return total
end

-- ペットIDが有効かどうか
function PetConfig.IsValid(petId)
	return petId and PetConfig.All[petId] ~= nil
end

-- ボーナス倍率を取得（旧IDも対応）
function PetConfig.GetBonus(petId)
	local info = PetConfig.All[petId]
	if not info then return 0 end
	return info.bonusPct or 0
end

-- 表示名を取得
function PetConfig.GetDisplayName(petId)
	local info = PetConfig.All[petId]
	if not info then return petId end
	return info.displayName or petId
end

-- レアリティを取得
function PetConfig.GetRarity(petId)
	local info = PetConfig.All[petId]
	if not info then return "Unknown" end
	return info.rarity or "Unknown"
end

-- モデル用のIDを取得（エイリアスの場合は実際のIDを返す）
function PetConfig.GetModelId(petId)
	local info = PetConfig.All[petId]
	if not info then return petId end
	return info.aliasOf or petId
end

-- 全ガチャ重みの合計を計算
function PetConfig.GetTotalWeight()
	local total = 0
	for _, item in ipairs(PetConfig.GachaPool) do
		total = total + item.weight
	end
	return total
end

-- 新規ペットIDのリストを取得（エイリアスを除く）
function PetConfig.GetNewPetIds()
	local ids = {}
	for id, info in pairs(PetConfig.All) do
		if not info.aliasOf then
			table.insert(ids, id)
		end
	end
	return ids
end

return PetConfig
