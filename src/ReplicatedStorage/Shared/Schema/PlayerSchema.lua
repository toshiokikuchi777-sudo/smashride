-- ReplicatedStorage/Shared/Schema/PlayerSchema.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Contracts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Contracts"))
local HammerShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HammerShopConfig"))

local PlayerSchema = {}

local function ensureArray(v)
  return (type(v) == "table") and v or {}
end

local function ensureNumber(v, fallback)
  v = tonumber(v)
  if v == nil then return fallback end
  return v
end

local function ensureStage(v)
  v = ensureNumber(v, 1)
  if v < 1 then v = 1 end
  return math.floor(v)
end

local function normalizeHammerId(id)
  if type(id) ~= "string" then return nil end

  local upper = string.upper(id)
  if upper == "NONE" then return "NONE" end
  if HammerShopConfig.Hammers[upper] then
    return upper
  end

  for hammerId, config in pairs(HammerShopConfig.Hammers) do
    if type(config.modelId) == "string" and string.upper(config.modelId) == upper then
      return hammerId
    end
  end

  return upper
end

-- 指示書 2/8: 生データを必ず安全な形に補正する
function PlayerSchema.Normalize(raw)
  raw = (type(raw) == "table") and raw or {}

  local base = Contracts.PlayerSchema

  local data = {
    total = ensureNumber(raw.total, base.total),
    ownedPets = ensureArray(raw.ownedPets),
    equippedPets = ensureArray(raw.equippedPets),

    -- 追加分（将来機能用）
    cansSmashedTotal = ensureNumber(raw.cansSmashedTotal, base.cansSmashedTotal),
    stage = ensureStage(raw.stage),
    unlockedHammers = ensureArray(raw.unlockedHammers),
    
    -- スケボーショップ用
    ownedSkateboards = ensureArray(raw.ownedSkateboards),
    equippedSkateboard = (type(raw.equippedSkateboard) == "string") and raw.equippedSkateboard or "NONE",
    
    -- ハンマーショップ用
    ownedHammers = ensureArray(raw.ownedHammers),
    equippedHammer = (type(raw.equippedHammer) == "string") and raw.equippedHammer or "NONE",

    -- 実績・イベント
    hasClaimedFeedback = raw.hasClaimedFeedback == true,
    claimedRainbowHammer = raw.claimedRainbowHammer == true,

    -- 集計用（各色の破壊数など）
    smashedCounts = (type(raw.smashedCounts) == "table") and raw.smashedCounts or {
      red = 0, blue = 0, green = 0, purple = 0, yellow = 0
    }
  }

  -- ペットの初期保証 (スターターペットを持っていない場合は付与)
  local hasStarter = false
  for _, petId in ipairs(data.ownedPets) do
    if petId == "Pet_Starter" then hasStarter = true break end
  end
  if not hasStarter then
    table.insert(data.ownedPets, 1, "Pet_Starter")
  end
  
  -- 装備が全空ならスターターをセット
  local anyEquipped = false
  for i = 1, 3 do
    if data.equippedPets[i] ~= "" then anyEquipped = true break end
  end
  if not anyEquipped then
    data.equippedPets[1] = "Pet_Starter"
  end
  
  -- スケボーの初期保証
  local hasBasicBoard = false
  for _, boardId in ipairs(data.ownedSkateboards) do
    if boardId == "BASIC" then hasBasicBoard = true break end
  end
  if not hasBasicBoard then
    table.insert(data.ownedSkateboards, 1, "BASIC")
  end
  
  -- ハンマーの初期保証
  local normalizedHammers = {}
  local seenHammers = {}
  for _, hammerId in ipairs(data.ownedHammers) do
    local normalizedId = normalizeHammerId(hammerId)
    if normalizedId and not seenHammers[normalizedId] then
      seenHammers[normalizedId] = true
      table.insert(normalizedHammers, normalizedId)
    end
  end
  data.ownedHammers = normalizedHammers

  data.equippedHammer = normalizeHammerId(data.equippedHammer) or "NONE"
  if data.equippedHammer == "NONE" then
    data.equippedHammer = "NONE"
  end

  local hasBasicHammer = false
  for _, hammerId in ipairs(data.ownedHammers) do
    if hammerId == "BASIC" then hasBasicHammer = true break end
  end
  if not hasBasicHammer then
    table.insert(data.ownedHammers, 1, "BASIC")
  end

  if data.equippedHammer ~= "NONE" then
    local ownsEquipped = false
    for _, hammerId in ipairs(data.ownedHammers) do
      if hammerId == data.equippedHammer then
        ownsEquipped = true
        break
      end
    end
    if not ownsEquipped then
      data.equippedHammer = "BASIC"
    end
  end

  return data
end

-- 下位互換性のためのエイリアス
function PlayerSchema.ValidateAndFix(raw, petConfigAll, slots)
    local data = PlayerSchema.Normalize(raw)
    return data, { reset = false, fixed = {} } -- report は一旦簡易化
end

function PlayerSchema.Default()
    return PlayerSchema.Normalize({})
end

function PlayerSchema.VERSION()
    return 1
end

return PlayerSchema
