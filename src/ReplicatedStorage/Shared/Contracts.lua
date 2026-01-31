-- ReplicatedStorage/Shared/Contracts.lua
local Contracts = {}

-- 保存データのスキーマ（最低限）
Contracts.PlayerSchema = {
  total = 0,
  ownedPets = {},
  equippedPets = {"", "", ""},

  -- 追加予定（将来機能）
  cansSmashedTotal = 0, -- 缶破壊累計（ハンマー解放用）
  stage = 1,            -- ステージ進行（上位ルーレット解放用）
  unlockedHammers = {}, -- 任意：キャッシュ（なくてもOK）
  
  -- スケボーショップ
  ownedSkateboards = {},
  equippedSkateboard = "BASIC",
  
  -- ハンマーショップ
  ownedHammers = {},
  -- ハンマーショップ
  equippedHammer = "BASIC",
  
  -- カラー別破壊数
  smashedCounts = {
    red = 0, blue = 0, green = 0, purple = 0, yellow = 0
  },
  
  -- プロモーション報酬
  hasClaimedFeedback = false,
  claimedRainbowHammer = false
}

-- ルーレット（ガチャ）の“ティア”定義（将来追加）
Contracts.GachaTiers = {
  BASIC = "BASIC",
  RARE = "RARE",
  LEGEND = "LEGEND",
}

return Contracts