-- ServerScriptService/Services/GrindService.lua
-- レールグラインドのサーバー側処理

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrindService = {}

-- 設定読み込み
local GrindConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GrindConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

-- プレイヤーごとのグラインド状態
local playerGrindStates = {}
local playerLastGrindTime = {} -- クールダウン用

-- SkateboardService への参照（遅延取得）
local SkateboardService

local function getSkateboardService()
	if not SkateboardService then
		SkateboardService = require(script.Parent:WaitForChild("SkateboardService"))
	end
	return SkateboardService
end

-- レールの方向と情報を取得
local function getRailInfo(railPart)
	local cf = railPart.CFrame
	local size = railPart.Size
	local direction, length, thickness
	
	if size.X > size.Y and size.X > size.Z then
		direction = cf.RightVector
		length = size.X
		thickness = size.Y
	elseif size.Z > size.X and size.Z > size.Y then
		direction = cf.LookVector
		length = size.Z
		thickness = size.Y
	else
		direction = cf.UpVector
		length = size.Y
		thickness = size.X
	end
	
	return direction, length, thickness
end

-- プレイヤーの近くにあるレールを検出
local function findNearestRail(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	
	local rails = CollectionService:GetTagged(Constants.Tag.GrindRail)
	local nearestRail = nil
	local nearestDistance = GrindConfig.DetectionRadius
	
	for _, rail in ipairs(rails) do
		if rail:IsA("BasePart") then
			local railDir, railLength, railThickness = getRailInfo(rail)
			local relativePos = rootPart.Position - rail.Position
			local projection = relativePos:Dot(railDir)
			
			-- 線分内（長さの範囲内）にクランプ
			local clampedProjection = math.clamp(projection, -railLength/2, railLength/2)
			local nearestPointOnLine = rail.Position + (railDir * clampedProjection)
			
			local distance = (rootPart.Position - nearestPointOnLine).Magnitude
			local heightDiff = math.abs(nearestPointOnLine.Y - rootPart.Position.Y)
			
			-- 修正: レールの長さの範囲外にいる場合は検出しない（ガタつき防止）
			local isWithinLength = math.abs(projection) <= (railLength / 2)
			
			if distance < nearestDistance and heightDiff < GrindConfig.DetectionHeight and isWithinLength then
				nearestDistance = distance
				nearestRail = rail
			end
		end
	end
	
	return nearestRail
end

-- グラインド開始
local function startGrind(player, rail)
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end
	
	-- 既にグラインド中の場合は何もしない
	if player:GetAttribute(Constants.Attr.IsGrinding) then return end
	
	-- クールダウンチェック
	local lastTime = playerLastGrindTime[player] or 0
	if tick() - lastTime < 0.5 then return end
	
	print("[GrindService] Starting grind for:", player.Name)
	
	-- Humanoidの歩行を無効化
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0 -- ジャンプも無効化
	humanoid.PlatformStand = true -- Humanoidの制御を完全に無効化
	rootPart.Anchored = true -- 物理を止めて位置を固定（ガタつき防止）
	
	-- グラインド状態を設定
	player:SetAttribute(Constants.Attr.IsGrinding, true)
	
	-- グラインド状態を保存
	playerGrindStates[player] = {
		rail = rail,
		startTime = tick(),
		lastJumpTime = 0,
		originalWalkSpeed = originalWalkSpeed,
		grindDistance = 0, -- レールに沿って進んだ距離
	}
	
	-- クライアントに通知
	local GrindStarted = Net.E("GrindStarted")
	if GrindStarted then
		GrindStarted:FireClient(player, rail)
	end
end

-- グラインド終了
local function endGrind(player, reason, exitVelocity)
	if not player:GetAttribute(Constants.Attr.IsGrinding) then 
		print("[GrindService/DEBUG] endGrind called but player not grinding:", player.Name)
		return 
	end
	
	print("[GrindService] Ending grind for:", player.Name, "Reason:", reason or "unknown")
	
	local state = playerGrindStates[player]
	playerLastGrindTime[player] = tick() -- 終了時刻を記録
	
	-- Humanoidの状態を戻す
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		
		if rootPart then
			rootPart.Anchored = false -- 物理演算を再開
			if exitVelocity then
				rootPart.AssemblyLinearVelocity = exitVelocity
			end
		end
		
		if humanoid and state and state.originalWalkSpeed then
			humanoid.WalkSpeed = state.originalWalkSpeed
			humanoid.JumpPower = 50 -- デフォルト値に戻す
			humanoid.PlatformStand = false -- Humanoidの制御を復元
		end
	end
	
	-- グラインド状態をクリア
	player:SetAttribute(Constants.Attr.IsGrinding, false)
	playerGrindStates[player] = nil
	
	-- クライアントに通知
	local GrindEnded = Net.E("GrindEnded")
	if GrindEnded then
		GrindEnded:FireClient(player)
	end
end

-- グラインド物理の更新（Heartbeatで呼ばれる）
local function updateGrindPhysics(player)
	local state = playerGrindStates[player]
	if not state then return end
	
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	local rail = state.rail
	if not rail or not rail.Parent then
		endGrind(player, "rail_destroyed")
		return
	end
	
	-- 重力で加速しないように速度をリセット
	rootPart.AssemblyLinearVelocity = Vector3.zero
	
	-- レールの情報を取得
	local railDir, railLength, railThickness = getRailInfo(rail)
	
	-- 現在の位置からレール線分への最短地点を計算
	local relativePos = rootPart.Position - rail.Position
	local projection = relativePos:Dot(railDir)
	
	-- プレイヤーの向き（LookVector）を使ってレール進行方向を決定
	local playerLookVector = rootPart.CFrame.LookVector
	local directionalRailDir = railDir
	if playerLookVector:Dot(directionalRailDir) < 0 then
		directionalRailDir = -directionalRailDir
	end
	
	-- レールに沿って進む距離を計算
	local deltaTime = 1/60
	local moveDistance = GrindConfig.GrindSpeed * deltaTime
	
	-- 新しい位置を計算
	-- directionalRailDir が railDir と同じか逆かによって符号を変える
	local directionMultiplier = (directionalRailDir:Dot(railDir) > 0) and 1 or -1
	local nextProjection = projection + (directionMultiplier * moveDistance)
	
	-- レールから外れたら終了
	if math.abs(nextProjection) > (railLength / 2) then
		-- 終了時に前方向への速度を与える
		local exitVelocity = directionalRailDir * (GrindConfig.GrindSpeed * 0.5)
		endGrind(player, "end_of_rail", exitVelocity)
		return
	end
	
	local nextPointOnLine = rail.Position + (railDir * nextProjection)
	
	-- Y座標をレールの上面に合わせる
	-- スケボーの下にレールが来るように 4.5 スタッドに調整
	local targetY = nextPointOnLine.Y + (railThickness / 2) + 4.5
	local nextFinalPos = Vector3.new(nextPointOnLine.X, targetY, nextPointOnLine.Z)
	
	-- CFrameを直接設定（向きは進行方向）
	local targetCFrame = CFrame.lookAt(nextFinalPos, nextFinalPos + directionalRailDir)
	rootPart.CFrame = targetCFrame
	
	-- デバッグログ
	state.updateCount = (state.updateCount or 0) + 1
	if state.updateCount % 60 == 0 then
		print(string.format("[GrindService/DEBUG] Grinding, pos: %.2f, %.2f, %.2f", 
			rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z))
	end
end

-- グラインドからジャンプ離脱
local function handleGrindJump(player)
	if not player:GetAttribute(Constants.Attr.IsGrinding) then return end
	
	local state = playerGrindStates[player]
	if not state then return end
	
	-- クールダウンチェック
	local timeSinceLastJump = tick() - (state.lastJumpTime or 0)
	if timeSinceLastJump < GrindConfig.JumpOffCooldown then return end
	
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end
	
	print("[GrindService] Jump off grind for:", player.Name)
	
	-- レールの方向を取得
	local railDir = getRailInfo(state.rail)
	
	-- プレイヤーの向きに応じて前方向を決定
	local playerLookVector = rootPart.CFrame.LookVector
	if playerLookVector:Dot(railDir) < 0 then
		railDir = -railDir
	end
	
	-- ジャンプ力を適用（上向き + 前方向）
	local jumpVelocity = Vector3.new(0, GrindConfig.JumpOffUpwardForce, 0) + 
	                     railDir * GrindConfig.JumpOffForwardForce
	
	rootPart.AssemblyLinearVelocity = jumpVelocity
	
	-- Humanoid のジャンプ状態を設定
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	
	-- ジャンプ時刻を記録
	state.lastJumpTime = tick()
	
	-- グラインド終了
	endGrind(player, "jump_off")
end

-- メインループ（レール検出とグラインド物理）
local function onHeartbeat()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character then continue end
		
		-- スケートボード装備チェック
		local SS = getSkateboardService()
		if not SS or not SS.IsEquipped(player) then
			-- スケートボード未装備の場合、グラインド中なら終了
			if player:GetAttribute(Constants.Attr.IsGrinding) then
				endGrind(player, "skateboard_unequipped")
			end
			continue
		end
		
		local isGrinding = player:GetAttribute(Constants.Attr.IsGrinding)
		
		if isGrinding then
			-- グラインド中の場合、物理処理を更新
			local state = playerGrindStates[player]
			if state then
				updateGrindPhysics(player)
			end
		else
			-- グラインド中でない場合、レールを検出
			local nearestRail = findNearestRail(character)
			if nearestRail then
				startGrind(player, nearestRail)
			end
		end
	end
end

function GrindService.Init()
	print("[GrindService] Init")
	
	-- ジャンプ離脱イベント
	local SkateboardGrindJump = Net.E("SkateboardGrindJump")
	if SkateboardGrindJump then
		SkateboardGrindJump.OnServerEvent:Connect(function(player)
			handleGrindJump(player)
		end)
	end
	
	-- メインループ開始
	-- RunService.Heartbeat:Connect(onHeartbeat)
	
	-- プレイヤー退出時のクリーンアップ
	Players.PlayerRemoving:Connect(function(player)
		if player:GetAttribute(Constants.Attr.IsGrinding) then
			endGrind(player, "player_leaving")
		end
		playerGrindStates[player] = nil
	end)
end

return GrindService
