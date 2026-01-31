-- FaceTargetService.lua
-- 顔ターゲットのスポーン、HP管理、報酬処理

local FaceTargetService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)
local FaceTargetConfig = require(ReplicatedStorage.Shared.Config.FaceTargetConfig)
local MoneyDrop = require(game:GetService("ServerScriptService").Core.MoneyDrop)

-- 状態管理
local activeTargets = {} -- [targetId] = {model, type, hp, maxHP}
local targetTemplates = nil

-- Remote定義
Net.E(Constants.Events.FaceTargetSpawned)
Net.E(Constants.Events.FaceTargetHit) -- クライアントからのヒット通知
Net.E(Constants.Events.FaceTargetDamaged) -- サーバーからの更新通知
Net.E(Constants.Events.FaceTargetDestroyed)
Net.E(Constants.Events.FaceTargetExpiring) -- 消滅予告

-- 初期化
function FaceTargetService.Init()
	print("[FaceTargetService] 初期化開始")
	
	-- 起動時に既存のターゲットがあれば掃除
	local folder = workspace:FindFirstChild("FaceTargets")
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
		print("[FaceTargetService] 起動時の古いターゲットを掃除しました")
	end
	
	-- テンプレートフォルダの確認
	local templates = ServerStorage:FindFirstChild("Templates")
	if templates then
		targetTemplates = templates:FindFirstChild("FaceTargets")
	end
	
	-- ヒットリクエストの受信設定
	Net.On(Constants.Events.FaceTargetHit, FaceTargetService.OnHit)
	
	print("[FaceTargetService] 初期化完了")
end

-- 顔ターゲットをスポーンさせる
function FaceTargetService.SpawnFaceTarget(targetType, targetPosition, spawnPart)
	if not targetTemplates then
		local templates = ServerStorage:FindFirstChild("Templates")
		if templates then targetTemplates = templates:FindFirstChild("FaceTargets") end
	end
	if not targetTemplates then return end
	
	local template = targetTemplates:FindFirstChild("Face_" .. targetType)
	if not template then return end
	
	local targetId = HttpService:GenerateGUID(false)
	local model = template:Clone()
	local config = FaceTargetConfig.TargetTypes[targetType]
	
	-- 1. スケールを適用
	model:ScaleTo(config.scale)
	
	-- [FIX] コリジョンをモデル形状にピッタリ合わせ、歪みを防ぐ
	local handle = model:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		local mesh = handle:FindFirstChildWhichIsA("SpecialMesh")
		if mesh then
			-- 特殊メッシュ（顔用）
			local visualSize = handle.Size * mesh.Scale
			local shrinkH = 0.8
			local shrinkV = 0.95
			local targetCollisionSize = Vector3.new(visualSize.X * shrinkH, visualSize.Y * shrinkV, visualSize.Z * shrinkH)
			handle.Size = targetCollisionSize
			mesh.Scale = Vector3.new(1/shrinkH, 1/shrinkV, 1/shrinkH)
		elseif handle:IsA("MeshPart") or handle:IsA("UnionOperation") then
			-- メッシュパート（豚用など）
			handle.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
		end
	end

	-- 正しい回転 (横長・直立)
	-- [FIX] Z軸回転は縦長になるため廃止。モデルそのままの向き（0,0,0）を基準にする
	local rotation = CFrame.Angles(0, 0, 0)
	
	-- 2. 地面の高さを決定
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
	
	-- 3. モデルを配置 (少しだけ浮かせて「落とす」)
	model:PivotTo(CFrame.new(targetPosition.X, groundY + 4, targetPosition.Z) * rotation)
	
	-- 4. 物理設定（強制的に接地させ、倒れないように制御）
	local primaryPart = model.PrimaryPart or handle
	if primaryPart then
		local attachment = Instance.new("Attachment")
		attachment.Name = "StayUprightAttachment"
		attachment.Parent = primaryPart
		
		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Attachment0 = attachment
		alignOrientation.CFrame = CFrame.new() * rotation
		alignOrientation.MaxTorque = 1000000
		alignOrientation.Responsiveness = 200
		alignOrientation.Parent = primaryPart
		
		Debris:AddItem(alignOrientation, 2.5)
		Debris:AddItem(attachment, 2.5)
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true
			part.CanTouch = true
			part.Velocity = Vector3.new(0, -20, 0) -- 強力に接地させる
		end
	end
	
	-- 名前と親子付け
	model.Name = "FaceTarget_" .. targetId
	model.Parent = workspace:FindFirstChild("FaceTargets") or (function()
		local f = Instance.new("Folder", workspace)
		f.Name = "FaceTargets"
		return f
	end)()
	
	-- 5. 数秒後に位置を固定 (埋まりを防ぐために再度アンカー)
	task.delay(2.1, function()
		if model.Parent then
			-- 最終的な姿勢補正（倒れていたら直す）
			local currentPivot = model:GetPivot()
			model:PivotTo(CFrame.new(currentPivot.Position) * rotation)
			
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.Velocity = Vector3.zero
					part.RotVelocity = Vector3.zero
				end
			end
			print(string.format("[FaceTargetService] 接地固定完了: Y=%.2f", currentPivot.Position.Y))
		end
	end)
	
	-- 属性設定
	model:SetAttribute(FaceTargetConfig.AttrTargetId, targetId)
	model:SetAttribute(FaceTargetConfig.AttrHP, config.maxHP)
	model:SetAttribute(FaceTargetConfig.AttrMaxHP, config.maxHP)
	
	model.Parent = workspace:FindFirstChild("FaceTargets") or (function()
		local f = Instance.new("Folder")
		f.Name = "FaceTargets"
		f.Parent = workspace
		return f
	end)()
	
	activeTargets[targetId] = {
		model = model,
		targetType = targetType,
		hp = config.maxHP,
		maxHP = config.maxHP,
		spawnedAt = os.time()
	}
	
	-- クライアント通知
	Net.Fire(Constants.Events.FaceTargetSpawned, {
		targetId = targetId,
		targetType = targetType,
		position = model:GetPivot().Position, -- 現在の位置を送信
		maxHP = config.maxHP
	})
	
	-- 自動消滅タイマー
	local fadeBefore = 3 -- 3秒前からフェードアウト開始
	if config.despawnSeconds > fadeBefore then
		task.delay(config.despawnSeconds - fadeBefore, function()
			if activeTargets[targetId] then
				print("[FaceTargetService] フェードアウト開始:", targetId, "残り", fadeBefore, "秒")
				Net.Fire(Constants.Events.FaceTargetExpiring, { targetId = targetId, duration = fadeBefore })
			end
		end)
	end

	task.delay(config.despawnSeconds, function()
		print("[FaceTargetService] 自動消滅タイマー発動:", targetId, config.despawnSeconds, "秒経過")
		FaceTargetService.DespawnTarget(targetId, "TIMEOUT")
	end)
	
	print("[FaceTargetService] ターゲットスポーン:", targetType, targetId, "消滅まで", config.despawnSeconds, "秒")
	return targetId
end

-- ヒット処理
function FaceTargetService.OnHit(player, targetId)
	local data = activeTargets[targetId]
	if not data then 
		-- 自分の管理対象ではないID（豚など）は無視する
		return 
	end
	
	if not data.model or data.isDestroying then 
		return 
	end
	
	print(string.format("[FaceTargetService] 🔨 ヒット受信: %s -> %s (HP: %d)", player.Name, targetId:sub(1,8), data.hp))
	
	data.hp = math.max(0, data.hp - 1)
	data.model:SetAttribute(FaceTargetConfig.AttrHP, data.hp)
	
	Net.Fire(Constants.Events.FaceTargetDamaged, {
		targetId = targetId,
		newHP = data.hp,
		hitterUserId = player.UserId
	})

	-- [FIX] ショックウェーブを発生させる
	local CanService = require(script.Parent.CanService)
	CanService.CheckAndTriggerShockwave(player, data.model:GetPivot().Position)
	
	if data.hp <= 0 then
		print("[FaceTargetService] ⚔️ 破壊確定:", targetId:sub(1,8))
		data.isDestroying = true -- 重複処理ガード
		FaceTargetService.OnDestroyed(targetId, player)
	end
end

-- 破壊時の処理
function FaceTargetService.OnDestroyed(targetId, destroyer)
	local data = activeTargets[targetId]
	if not data or data.alreadyDestroyed then return end
	data.alreadyDestroyed = true
	
	local config = FaceTargetConfig.TargetTypes[data.targetType]
	local model = data.model
	local pos = model and model:GetPivot().Position or Vector3.new(0,0,0)
	
	-- ★ 最優先: まずモデルを即座に消す (プレイヤーへの視覚的反応を最速に)
	FaceTargetService.DespawnTarget(targetId, "DESTROYED")
	
	-- 周辺の全プレイヤーを検索（報酬共有）
	local eligiblePlayers = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dist = (hrp.Position - pos).Magnitude
			if dist <= FaceTargetConfig.RewardShareRadius then
				table.insert(eligiblePlayers, p)
			end
		end
	end
	
	-- 破壊者がリストにいない場合は追加
	local isDestroyerInList = false
	for _, p in ipairs(eligiblePlayers) do
		if p == destroyer then isDestroyerInList = true; break end
	end
	if not isDestroyerInList and destroyer then
		table.insert(eligiblePlayers, destroyer)
	end
	
	local playerCount = #eligiblePlayers
	print("[FaceTargetService] ターゲット破壊! 共有人数:", playerCount)
	
	if playerCount > 0 then
		local CanService = require(script.Parent.CanService) -- 報酬加算のために必要
		local totalAmount = config.rewardAmount
		local amountPerPlayer = math.floor(totalAmount / playerCount)
		
		-- 視覚的な演出コインを派手に弾けさせる (出現数を大幅に削減: 6 -> 2)
		MoneyDrop.SpawnVisualMoney(pos, 2, 9.0)
		
		for _, p in ipairs(eligiblePlayers) do
			-- 直接スコアを加算 (確実な受け取り)
			CanService.AddScore(p, amountPerPlayer)
			print("[FaceTargetService] 報酬直接付与:", p.Name, "額:", amountPerPlayer)

			-- 💰 ポイント獲得UI（ポップアップ）を出す
			Net.E(Constants.Events.MoneyCollected):FireClient(p, pos, amountPerPlayer)

			-- 個別にサマリーUIを表示させる
			-- 【重要】Net.E(鍵):FireClient(プレイヤー, データ) の形式で送る
			Net.E(Constants.Events.FaceTargetDestroyed):FireClient(p, {
				targetId = targetId,
				displayName = config.displayName,
				totalReward = amountPerPlayer
			})
		end
	else
		-- 誰もいない場合は演出のみ (少数・巨大)
		MoneyDrop.SpawnVisualMoney(pos, 3, 9.0)
	end
end

-- 削除処理
function FaceTargetService.DespawnTarget(targetId, reason)
	local data = activeTargets[targetId]
	if not data then return end
	
	if data.model then
		data.model:Destroy()
	end
	
	activeTargets[targetId] = nil
	print("[FaceTargetService] ターゲット削除:", targetId, "理由:", reason)
end

-- 全ターゲットを一括削除（イベント終了時用）
function FaceTargetService.ClearAllTargets()
	print("[FaceTargetService] 全ターゲットを一括削除中...")
	local count = 0
	for targetId, _ in pairs(activeTargets) do
		FaceTargetService.DespawnTarget(targetId, "EVENT_END")
		count = count + 1
	end
	print(string.format("[FaceTargetService] 一括削除完了: %d 個のターゲットを削除", count))
end

return FaceTargetService
