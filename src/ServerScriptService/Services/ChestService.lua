-- ChestService.lua
-- 宝箱のスポーン、Claim、Despawn処理

local ChestService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local ChestConfig = require(ReplicatedStorage.Shared.Config.ChestConfig)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)
local MoneyDrop = require(game:GetService("ServerScriptService").Core.MoneyDrop)
local CanService = require(game:GetService("ServerScriptService").Services.CanService)

-- 状態管理
local activeChests = {}
-- テンプレートは関数内で取得

-- Remote定義
Net.E("ChestSpawned")
Net.E("ChestDespawned")
Net.E("ChestClaimed")
Net.E("ChestClaimRequest")

-- 初期化
function ChestService.Init()
	print("[ChestService] 初期化開始")
	
	-- Claimリクエストの受信設定
	Net.On("ChestClaimRequest", ChestService.OnClaimRequest)
	
	print("[ChestService] 初期化完了")
end

-- 宝箱をスポーンさせる
function ChestService.SpawnChest(chestType, targetPosition)
	local templates = ServerStorage:FindFirstChild("Templates")
	local chestTemplates = templates and templates:FindFirstChild("Chests")
	
	-- Workspace からも探す（Argon 同期や手動配置の考慮）
	if not chestTemplates then
		chestTemplates = workspace:FindFirstChild("Chests")
	end
	
	if not chestTemplates then 
		warn("[ChestService] Chests folder missing in ServerStorage.Templates and Workspace")
		return 
	end
	
	local template = chestTemplates:FindFirstChild("Chest_" .. chestType)
	if not template then
		warn("[ChestService] テンプレートが見つかりません:", chestType)
		return
	end
	
	local chestId = game:GetService("HttpService"):GenerateGUID(false)
	local chestModel = template:Clone()
	
	-- スポーン位置の決定(地面接地)
	local spawnPos = targetPosition or ChestConfig.GetRandomSpawnPosition()
	
	-- Raycastで地面を探す
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {chestModel}
	
	local rayResult = game.Workspace:Raycast(spawnPos, Vector3.new(0, -500, 0), raycastParams)
	local finalPos = spawnPos
	if rayResult then
		-- 地面の少し上に配置 (めり込み防止)
		-- 宝箱の高さの半分を加算して、底面が地面に接するようにする
		local chestHeight = chestModel:GetExtentsSize().Y
		finalPos = rayResult.Position + Vector3.new(0, chestHeight / 2, 0)
	end
	
	-- モデルを配置
	chestModel:PivotTo(CFrame.new(finalPos))
	chestModel.Name = "Chest_" .. chestId
	
	local chestData = ChestConfig.ChestTypes[chestType]
	local despawnAt = os.time() + chestData.despawnSeconds
	local canClaimAt = workspace:GetServerTimeNow() + (ChestConfig.ClaimSpawnDelay or 1.5)
	
	chestModel:SetAttribute("ChestId", chestId)
	chestModel:SetAttribute("ChestType", chestType)
	chestModel:SetAttribute("DespawnAt", despawnAt)
	chestModel:SetAttribute("CanClaimAt", canClaimAt)
	
	chestModel.Parent = game.Workspace.Chests
	
	activeChests[chestId] = {
		model = chestModel,
		chestType = chestType,
		spawnedAt = os.time(),
		canClaimAt = canClaimAt,
		despawnAt = despawnAt,
		claimed = false,
		claimedBy = nil,
		claimedPlayers = {}
	}
	
	-- 全員にスポーンを通知 (VFX・UI用)
	Net.Fire("ChestSpawned", {
		chestId = chestId,
		chestType = chestType,
		position = finalPos,
		despawnAt = despawnAt,
		canClaimAt = canClaimAt
	})
	
	print("[ChestService] 宝箱スポーン:", chestType, chestId)
	
	-- 時間切れDespawnをスケジュール
	task.delay(chestData.despawnSeconds, function()
		ChestService.DespawnChest(chestId, "TIMEOUT")
	end)
	
	return chestId
end

-- Claimリクエスト処理 (RemoteFunction用)
function ChestService.OnClaimRequest(player, chestId)
	return ChestService.HandleClaimRequest(player, chestId)
end

-- 先着Claim処理
function ChestService.HandleClaimRequest(player, chestId)
	local chestInfo = activeChests[chestId]
	
	-- 検証1: 宝箱が存在するか、すでに取得されていないか
	if not chestInfo then
		warn("[ChestService] Claim失敗: 宝箱データが見つかりません ID=" .. tostring(chestId))
		return
	end
	if not chestInfo.model or not chestInfo.model.Parent then
		warn("[ChestService] Claim失敗: 宝箱モデルが削除されています ID=" .. tostring(chestId))
		return
	end
	if chestInfo.claimed then
		warn("[ChestService] Claim失敗: すでに取得済みです ID=" .. tostring(chestId))
		return
	end
	
	-- 検証2: 取得猶予時間（着地待ち）を過ぎているか
	local now = workspace:GetServerTimeNow()
	if now < chestInfo.canClaimAt then
		warn(string.format("[ChestService] Claim失敗: 着地前です (残り %.2f秒)", chestInfo.canClaimAt - now))
		return
	end
	
	-- 検証3: プレイヤーが近いか
	local character = player.Character
	if not character then 
		warn("[ChestService] Claim失敗: キャラクターが見つかりません")
		return 
	end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then 
		warn("[ChestService] Claim失敗: HRPが見つかりません")
		return 
	end
	
	local primaryPart = chestInfo.model.PrimaryPart
	if not primaryPart then 
		warn("[ChestService] Claim失敗: 宝箱のPrimaryPartが未設定です")
		return 
	end

	local chestPos = primaryPart.Position
	local distance = (hrp.Position - chestPos).Magnitude
	
	if distance > ChestConfig.ClaimDistance then
		warn(string.format("[ChestService] Claim失敗: 距離不足 (プレイヤー=%s, 距離=%.2f, 最大=%d)", 
			player.Name, distance, ChestConfig.ClaimDistance))
		return
	end
	
	-- ロック: Claimを確定
	chestInfo.claimed = true
	chestInfo.claimedBy = player.UserId
	chestInfo.model:SetAttribute("Claimed", true)
	
	-- 報酬付与（ハンマーで叩いたプレイヤーに直接付与）
	local chestData = ChestConfig.ChestTypes[chestInfo.chestType]
	local totalReward = chestData.claimerReward + chestData.nearbyReward
	
	-- プレイヤーに直接スコアを加算
	CanService.AddScore(player, totalReward)
	print(string.format("[ChestService] 報酬付与: %s に %d ポイント", player.Name, totalReward))
	
	-- コインを視覚効果として飛ばす（チェック付き）
	if MoneyDrop and MoneyDrop.SpawnVisualMoney then
		MoneyDrop.SpawnVisualMoney(chestPos, 3)
	end
	
	-- コイン取得音と報酬額を送信（クライアントへ通知）
	Net.E("MoneyCollected"):FireClient(player, chestPos, totalReward)
	print(string.format("[ChestService] 報酬UIデータを送信: %s (額: %d)", player.Name, totalReward))
	
	-- 通知用の変数
	local nearbyUserIds = {}
	
	-- 全員に通知
	Net.Fire("ChestClaimed", {
		chestId = chestId,
		chestType = chestInfo.chestType,
		claimerUserId = player.UserId,
		claimerName = player.Name,
		rewards = {
			claimer = chestData.claimerReward,
			nearby = chestData.nearbyReward
		},
		centerPos = chestPos,
		nearbyCount = #nearbyUserIds,
		nearbyPlayers = nearbyUserIds
	})
	
	print("[ChestService] Claim成功:", player.Name, chestInfo.chestType)
	
	-- 演出猶予後に消去
	task.delay(0.8, function()
		ChestService.DespawnChest(chestId, "CLAIMED")
	end)
	
	return true
end

-- 宝箱をDespawn
function ChestService.DespawnChest(chestId, reason)
	local chestInfo = activeChests[chestId]
	if not chestInfo then return end
	
	-- TIMEOUTの場合はClaim済ならスキップ
	if reason == "TIMEOUT" and chestInfo.claimed then
		return
	end
	
	-- モデルを削除
	if chestInfo.model and chestInfo.model.Parent then
		chestInfo.model:Destroy()
	end
	
	-- アクティブリストから削除
	activeChests[chestId] = nil
	
	-- 全員に通知
	Net.Fire("ChestDespawned", {
		chestId = chestId,
		reason = reason
	})
end

-- 全ての宝箱をクリア
function ChestService.ClearAllChests()
	for chestId, _ in pairs(activeChests) do
		ChestService.DespawnChest(chestId, "CLEAR")
	end
end

return ChestService
