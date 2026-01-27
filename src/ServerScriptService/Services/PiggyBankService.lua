-- PiggyBankService.lua
-- 豚の貯金箱のスポーン、HP管理、報酬処理

local PiggyBankService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Net = require(ReplicatedStorage.Shared.Net)
local PiggyBankConfig = require(ReplicatedStorage.Shared.Config.PiggyBankConfig)
local MoneyDrop = require(game:GetService("ServerScriptService").Core.MoneyDrop)

-- 状態管理
local activeTargets = {} -- [targetId] = {model, type, hp, maxHP}
local targetTemplates = nil

-- RemoteはFaceTargetServiceと共通のものを使用 (互換性維持)
-- Net.E("FaceTargetSpawned") 等はEventService/FaceTargetService側で定義済み

-- 初期化
function PiggyBankService.Init()
	print("[PiggyBankService] 初期化開始")
	
	-- テンプレートフォルダの確認
	local templates = ServerStorage:FindFirstChild("Templates")
	if templates then
		targetTemplates = templates:FindFirstChild("FaceTargets")
	end
	
	-- ヒットリクエストの受信設定 (FaceTargetServiceと同じ関数名だが別管理)
	Net.On("FaceTargetHit", PiggyBankService.OnHit)
	
	print("[PiggyBankService] 初期化完了")
end

-- 豚の貯金箱をスポーンさせる
function PiggyBankService.SpawnPiggy(targetType, targetPosition, spawnPart)
	-- テンプレートを取得 (Workspaceの piggybank を優先使用)
	local template = workspace:FindFirstChild("piggybank")
	if not template then
		-- フォールバック: ServerStorage を見る
		if not targetTemplates then
			local t = ServerStorage:FindFirstChild("Templates")
			if t then targetTemplates = t:FindFirstChild("FaceTargets") end
		end
		if targetTemplates then
			template = targetTemplates:FindFirstChild("Face_" .. targetType)
		end
	end

	if not template then 
		print("[PiggyBankService] テンプレートが見つかりません: " .. targetType)
		return 
	end
	
	local targetId = HttpService:GenerateGUID(false)
	local model = template:Clone()
	local config = PiggyBankConfig.TargetTypes[targetType]
	
	-- スケールを適用
	model:ScaleTo(config.scale)
	
	-- コリジョン設定
	local handle = model:FindFirstChild("Handle")
	if handle and (handle:IsA("MeshPart") or handle:IsA("UnionOperation")) then
		handle.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	end

	local rotation = CFrame.Angles(0, 0, 0)
	
	-- 接地判定
	local groundY = targetPosition.Y
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {model, workspace:FindFirstChild("FaceTargets")}
	
	if spawnPart and spawnPart:IsA("BasePart") then
		groundY = spawnPart.Position.Y + (spawnPart.Size.Y / 2)
	else
		local rayResult = workspace:Raycast(targetPosition + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), rayParams)
		if rayResult then groundY = rayResult.Position.Y end
	end
	
	-- モデルを配置
	model:PivotTo(CFrame.new(targetPosition.X, groundY + 5, targetPosition.Z) * rotation)
	
	-- 物理設定（アンカー）
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
			part.CanTouch = true
		end
	end
	
	-- 名前と親子付け
	model.Name = "PiggyTarget_" .. targetId
	model.Parent = workspace:FindFirstChild("FaceTargets") or (function()
		local f = Instance.new("Folder", workspace)
		f.Name = "FaceTargets"
		return f
	end)()
	
	-- 属性設定
	model:SetAttribute(PiggyBankConfig.AttrTargetId, targetId)
	model:SetAttribute(PiggyBankConfig.AttrHP, config.maxHP)
	model:SetAttribute(PiggyBankConfig.AttrMaxHP, config.maxHP)
	model:SetAttribute("DisplayName", config.displayName)
	
	activeTargets[targetId] = {
		model = model,
		targetType = targetType,
		hp = config.maxHP,
		maxHP = config.maxHP,
		spawnedAt = os.time()
	}
	
	-- クライアント通知 (既存のキーを使用)
	Net.Fire("FaceTargetSpawned", {
		targetId = targetId,
		targetType = targetType,
		position = model:GetPivot().Position,
		maxHP = config.maxHP
	})
	
	-- 自動消滅タイマー
	task.delay(config.despawnSeconds, function()
		PiggyBankService.DespawnTarget(targetId, "TIMEOUT")
	end)
	
	print("[PiggyBankService] スポーン:", targetType, targetId)
	return targetId
end

-- ヒット処理
function PiggyBankService.OnHit(player, targetId)
	local data = activeTargets[targetId]
	if not data then 
		-- 自分の管理対象ではないID（顔など）は無視する
		return 
	end
	
	if not data.model or data.isDestroying then return end
	
	data.hp = math.max(0, data.hp - 1)
	data.model:SetAttribute(PiggyBankConfig.AttrHP, data.hp)
	
	Net.Fire("FaceTargetDamaged", {
		targetId = targetId,
		newHP = data.hp,
		hitterUserId = player.UserId
	})
	
	if data.hp <= 0 then
		data.isDestroying = true
		PiggyBankService.OnDestroyed(targetId, player)
	end
end

-- 破壊時の処理
function PiggyBankService.OnDestroyed(targetId, destroyer)
	local data = activeTargets[targetId]
	if not data or data.alreadyDestroyed then return end
	data.alreadyDestroyed = true
	
	local config = PiggyBankConfig.TargetTypes[data.targetType]
	local pos = data.model:GetPivot().Position
	
	PiggyBankService.DespawnTarget(targetId, "DESTROYED")
	
	-- 報酬付与
	local CanService = require(game:GetService("ServerScriptService").Services.CanService)
	CanService.AddScore(destroyer, config.rewardAmount)
	
	-- 演出
	MoneyDrop.SpawnVisualMoney(pos, config.coinCount, 9.0)
	Net.E("MoneyCollected"):FireClient(destroyer, pos, config.rewardAmount)
	
	Net.E("FaceTargetDestroyed"):FireClient(destroyer, {
		targetId = targetId,
		displayName = config.displayName,
		totalReward = config.rewardAmount
	})
end

-- 削除処理
function PiggyBankService.DespawnTarget(targetId, reason)
	local data = activeTargets[targetId]
	if not data then return end
	
	if data.model then data.model:Destroy() end
	activeTargets[targetId] = nil
	print("[PiggyBankService] ターゲット削除:", targetId, "理由:", reason)
end

-- 全削除
function PiggyBankService.ClearAllTargets()
	for targetId, _ in pairs(activeTargets) do
		PiggyBankService.DespawnTarget(targetId, "EVENT_END")
	end
end

return PiggyBankService
