-- ChestController.lua
-- クライアント側の宝箱制御(拾う入力、近接補助、VFX)

local ChestController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)
local ChestConfig = require(ReplicatedStorage.Shared.Config.ChestConfig)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- アクティブな宝箱を管理
local activeChests = {} -- { [chestId] = { chestType, position, despawnAt } }
local sentRequests = {} -- { [chestId] = time } 同じ宝箱への連打防止

-- 初期化
function ChestController.Init()
	print("[ChestController] 初期化開始")

	-- Remote受信
	Net.On(Constants.Events.ChestSpawned, ChestController.OnChestSpawned)
	Net.On(Constants.Events.ChestDespawned, ChestController.OnChestDespawned)
	Net.On(Constants.Events.ChestClaimed, ChestController.OnChestClaimed)

	-- 入力処理は CanController に一本化するため SetupInput は呼び出しません。

	print("[ChestController] 初期化完了")
end

-- ChestSpawned受信
function ChestController.OnChestSpawned(payload)
	local chestId = payload.chestId
	local chestType = payload.chestType
	local position = payload.position
	local despawnAt = payload.despawnAt

	-- アクティブリストに追加
	activeChests[chestId] = {
		chestType = chestType,
		position = position,
		despawnAt = despawnAt,
		canClaimAt = payload.canClaimAt or (workspace:GetServerTimeNow() + 1.5) -- 取得可能になる時刻
	}

	print("[ChestController] 宝箱スポーン:", chestType, chestId)

	-- VFX: スポーン演出
	local ChestVFX = require(ReplicatedStorage.Client.VFX.ChestVFX)
	ChestVFX.PlaySpawnEffect(chestId, chestType, position)
end

-- ChestDespawned受信
function ChestController.OnChestDespawned(payload)
	local chestId = payload.chestId
	local reason = payload.reason

	-- アクティブリストから削除
	activeChests[chestId] = nil
	sentRequests[chestId] = nil -- 消滅したらキャッシュも削除

	print("[ChestController] 宝箱Despawn:", chestId, reason)

	-- VFX: Despawn演出
	local ChestVFX = require(ReplicatedStorage.Client.VFX.ChestVFX)
	ChestVFX.PlayDespawnEffect(chestId, reason)
end

-- ChestClaimed受信
function ChestController.OnChestClaimed(payload)
	local chestId = payload.chestId
	local chestType = payload.chestType
	local claimerName = payload.claimerName
	local rewards = payload.rewards
	local centerPos = payload.centerPos
	local nearbyCount = payload.nearbyCount

	print("[ChestController] 宝箱Claim:", claimerName, chestType, "参加賞:", nearbyCount, "人")

	-- VFX: Claim演出
	local ChestVFX = require(ReplicatedStorage.Client.VFX.ChestVFX)
	ChestVFX.PlayClaimEffect(chestId, chestType, claimerName, centerPos, rewards)

	-- 自分が先着または参加賞を受け取った場合の通知
	if claimerName == player.Name then
		-- 先着通知
		ChestController.ShowRewardNotification("先着報酬!", rewards.claimer, chestType)
	else
		-- 参加賞チェック(距離で判定)
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = (hrp.Position - centerPos).Magnitude
				local chestData = ChestConfig.ChestTypes[chestType]
				if distance <= chestData.nearbyRadius then
					ChestController.ShowRewardNotification("参加賞!", rewards.nearby, chestType)
				end
			end
		end
	end
end

-- 報酬通知を表示
function ChestController.ShowRewardNotification(title, amount, chestType)
	local ChestEventUI = require(ReplicatedStorage.Client.UI.ChestEventUI)
	ChestEventUI.ShowRewardPopup(title, amount, chestType)
end

-- 最も近い宝箱を拾う
function ChestController.TryClaimNearestChest(isAuto)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- 最も近い宝箱を検索
	local nearestChestId = nil
	local nearestDistance = math.huge
	local anyChestNearby = false

	for chestId, chestInfo in pairs(activeChests) do
		local distance = (hrp.Position - chestInfo.position).Magnitude
		anyChestNearby = true
		if distance < nearestDistance then
			nearestDistance = distance
			if distance <= ChestConfig.ClaimDistance then
				nearestDistance = distance
				nearestChestId = chestId
			end
		end
	end

	-- 宝箱が見つかった場合、Claim要求を送信
	if nearestChestId then
		ChestController.RequestClaim(nearestChestId, isAuto)
	elseif not isAuto then
		-- 手動クリック時のみログを表示
		if anyChestNearby then
			print(string.format("[ChestController] 宝箱はありますが遠すぎます: 最短距離=%.2f, 限定距離=%d", 
				nearestDistance, ChestConfig.ClaimDistance))
		else
			print("[ChestController] アクティブな宝箱がリストにありません")
		end
	end
end

-- ハンマーヒット位置から最も近い宝箱を検索
function ChestController.FindNearestChest(position, maxDistance)
	local nearestChest = nil
	local nearestDistance = maxDistance or 10

	for chestId, chestData in pairs(activeChests) do
		local distance = (chestData.position - position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestChest = {chestId = chestId, distance = distance, chestType = chestData.chestType}
		end
	end

	return nearestChest
end

-- 特定の宝箱にClaimリクエストを送信
function ChestController.RequestClaim(chestId, isAuto)
	local chestInfo = activeChests[chestId]
	if not chestInfo then return end

	-- 着地待ちチェック (通信ラグを考慮して少し緩和)
	local now = workspace:GetServerTimeNow()
	if now < chestInfo.canClaimAt - 1.0 then -- 1秒の猶予
		print(string.format("[ChestController] まだ取得できません (残り %.2f秒)", chestInfo.canClaimAt - now))
		return
	end

	-- 連打防止チェック (0.5秒以内にリクエスト済みなら無視)
	if sentRequests[chestId] and (os.clock() - sentRequests[chestId] < 0.5) then
		return
	end

	print(string.format("[ChestController] 取得リクエスト(%s): ID=%s", 
		isAuto and "自動" or "手動", chestId))
	sentRequests[chestId] = os.clock()
	Net.Fire(Constants.Events.ChestClaimRequest, chestId)
end


return ChestController
