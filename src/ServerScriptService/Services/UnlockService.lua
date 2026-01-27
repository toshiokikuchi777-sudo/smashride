-- ServerScriptService/Services/UnlockService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local UnlockService = {}

local function isUnlocked(rule, state)
  if rule.default then return true end
  
  if rule.stage and (state.stage or 1) < rule.stage then 
    -- print("[UnlockService] Stage lock:", (state.stage or 1), "<", rule.stage)
    return false 
  end
  
  if rule.cansSmashedTotal then
    local current = state.cansSmashedTotal or 0
    if current < rule.cansSmashedTotal then
      -- print("[UnlockService] Smashed lock:", current, "<", rule.cansSmashedTotal)
      return false
    end
  end
  
  return true
end

-- ハンマーアンロック判定 - ハンマーショップ導入により無効化
--[[
function UnlockService.GetUnlockedHammers(state)
  local out = {}
  local rules = GameConfig.HammerUnlockRules or {}
  for hammerId, rule in pairs(rules) do
    if isUnlocked(rule, state) then
      out[hammerId] = true
    end
  end
  return out
end
--]]

-- profile例: { stage=1, cansSmashedTotal=0, ... }
-- ハンマーアンロック判定 - ハンマーショップ導入により無効化
--[[
function UnlockService.IsHammerUnlocked(profile, hammerId)
	local rule = GameConfig.HammerUnlockRules[hammerId]
	if not rule then return true end -- ルール未定義は解放扱い（開発中に詰まらない）
	if rule.default then return true end

	if rule.stage and (profile.stage or 1) < rule.stage then
		return false
	end
	if rule.cansSmashedTotal and (profile.cansSmashedTotal or 0) < rule.cansSmashedTotal then
		return false
	end
	return true
end
--]]

function UnlockService.CanUseHammer(hammerId, state)
  return UnlockService.IsHammerUnlocked(state, hammerId)
end

function UnlockService.CanUseGachaTier(tier, state)
  local rules = GameConfig.GachaTierRules or {}
  local rule = rules[tier]
  if not rule then return false end
  return isUnlocked(rule, state)
end

-- 指示書 8/8: クライアント同期用ペイロードの作成
function UnlockService.BuildSyncPayload(state)
  local payload = {
    hammers = {},
    gachaTiers = {},
  }

  -- ハンマーのチェック - ハンマーショップ導入により無効化
  --[[
  local hRules = GameConfig.HammerUnlockRules or {}
  for id, rule in pairs(hRules) do
    if isUnlocked(rule, state) then
      payload.hammers[id] = true
    end
  end
  --]]

  -- ガチャティアのチェック
  local gRules = GameConfig.GachaTierRules or {}
  for id, rule in pairs(gRules) do
    if isUnlocked(rule, state) then
      payload.gachaTiers[id] = true
    end
  end

  return payload
end

return UnlockService
