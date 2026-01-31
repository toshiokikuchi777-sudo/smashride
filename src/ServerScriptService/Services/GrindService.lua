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

-- カーブレールかどうかを判定
local function isCurvedRail(railPart)
	-- すべてのCurvedRailSegment、Semicircleをカーブレールとして扱う
	return railPart.Name:find("Curved") ~= nil or railPart.Name:find("Semicircle") ~= nil
end

-- カーブレールのタイプとセグメント番号を取得
local function getCurvedRailInfo(railPart)
	local name = railPart.Name
	
	-- CurvedRailSegment_Medium_0 のようなパターン
	local railType, segmentNum = name:match("CurvedRailSegment_(%w+)_(%d+)")
	if railType and segmentNum then
		return railType, tonumber(segmentNum), 11 -- Medium/Large は 0-11
	end
	
	-- CurvedRailSegment_0 のようなパターン(Small)
	segmentNum = name:match("CurvedRailSegment_(%d+)")
	if segmentNum then
		return "Small", tonumber(segmentNum), 11 -- Small は 0-11
	end
	
	-- SemicircleSegment_Reverse_0 のようなパターン
	local reverseNum = name:match("SemicircleSegment_Reverse_(%d+)")
	if reverseNum then
		return "SemicircleReverse", tonumber(reverseNum), 5 -- Semicircle Reverse は 0-5
	end
	
	-- SemicircleSegment_0 のようなパターン
	segmentNum = name:match("SemicircleSegment_(%d+)")
	if segmentNum then
		return "Semicircle", tonumber(segmentNum), 5 -- Semicircle は 0-5
	end
	
	return nil, nil, nil
end

-- カーブレールの次のセグメントを検索
local function findNextCurvedSegment(currentRail, direction)
	local railType, currentSegment, maxSegment = getCurvedRailInfo(currentRail)
	if not railType or not currentSegment then return nil end
	
	-- 進行方向に基づいて次のセグメント番号を決定
	local nextSegment = currentSegment + direction
	
	-- 範囲チェック(0-maxSegment)
	if nextSegment < 0 or nextSegment > maxSegment then
		return nil
	end
	
	-- 次のセグメント名を構築
	local nextSegmentName
	if railType == "Small" then
		nextSegmentName = "CurvedRailSegment_" .. nextSegment
	elseif railType == "Medium" or railType == "Large" then
		nextSegmentName = "CurvedRailSegment_" .. railType .. "_" .. nextSegment
	elseif railType == "Semicircle" then
		nextSegmentName = "SemicircleSegment_" .. nextSegment
	elseif railType == "SemicircleReverse" then
		nextSegmentName = "SemicircleSegment_Reverse_" .. nextSegment
	else
		return nil
	end
	
	-- 次のセグメントを検索
	local rails = CollectionService:GetTagged(Constants.Tags.GrindRail)
	
	for _, rail in ipairs(rails) do
		if rail.Name == nextSegmentName then
			return rail
		end
	end
	
	return nil
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
	
	local rails = CollectionService:GetTagged(Constants.Tags.GrindRail)
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
			
			-- 修正: レールの長さの範囲外に少し余裕を持たせる（開始しやすくするため）
			local isWithinLength = math.abs(projection) <= (railLength / 2 + 2)
			
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
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	rootPart.Anchored = true
	
	-- グラインド中の衝突判定を無効化
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	
	-- グラインド状態を設定
	player:SetAttribute(Constants.Attr.IsGrinding, true)
	
	-- プレイヤーの進行方向を最初に決定して保存
	local railDir = getRailInfo(rail)
	local playerLook = rootPart.CFrame.LookVector
	local worldDirection = railDir
	if playerLook:Dot(worldDirection) < 0 then
		worldDirection = -worldDirection
	end
	
	-- カーブレールの進行方向を決定
	local curvedRailDirection = nil
	if isCurvedRail(rail) then
		local railType, currentSegment, maxSegment = getCurvedRailInfo(rail)
		if currentSegment then
			-- セグメント番号が小さい方向を向いているか、大きい方向を向いているかを判定
			-- 簡易的に、セグメント番号が5以下なら順方向、6以上なら逆方向の可能性が高い
			-- より正確には、次のセグメントとの位置関係で判定
			local nextSegmentForward = findNextCurvedSegment(rail, 1)
			local nextSegmentBackward = findNextCurvedSegment(rail, -1)
			
			if nextSegmentForward and nextSegmentBackward then
				-- 両方向に次のセグメントがある場合、プレイヤーの向きで判定
				local forwardDir = (nextSegmentForward.Position - rail.Position).Unit
				local backwardDir = (nextSegmentBackward.Position - rail.Position).Unit
				
				if playerLook:Dot(forwardDir) > playerLook:Dot(backwardDir) then
					curvedRailDirection = 1 -- 順方向
				else
					curvedRailDirection = -1 -- 逆方向
				end
			elseif nextSegmentForward then
				curvedRailDirection = 1 -- 順方向のみ可能
			elseif nextSegmentBackward then
				curvedRailDirection = -1 -- 逆方向のみ可能
			else
				curvedRailDirection = 1 -- デフォルトは順方向
			end
		end
	end

	-- グラインド状態を保存
	playerGrindStates[player] = {
		rail = rail,
		previousRail = nil, -- 前のレールを記録
		startTime = tick(),
		lastJumpTime = 0,
		originalWalkSpeed = originalWalkSpeed,
		worldDirection = worldDirection, -- 進行方向を固定
		grindDistance = 0,
		curvedRailDirection = curvedRailDirection, -- カーブレールの進行方向(1=順方向, -1=逆方向)
	}
	
	-- クライアントに通知
	local GrindStarted = Net.E(Constants.Events.GrindStarted)
	if GrindStarted then
		GrindStarted:FireClient(player, rail)
	end
end

-- グラインド終了
local function endGrind(player, reason, exitVelocity, shouldJump)
	if not player:GetAttribute(Constants.Attr.IsGrinding) then return end
	
	-- 状態を即座にクリアして再入を防止
	player:SetAttribute(Constants.Attr.IsGrinding, false)
	local state = playerGrindStates[player]
	playerGrindStates[player] = nil
	playerLastGrindTime[player] = tick()
	
	print(string.format("[GrindService] endGrind: %s, Source: %s", player.Name, tostring(reason)))
	
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		
		if rootPart then
			if exitVelocity then
				-- ジャンプ時は速度を設定
				rootPart.Anchored = false
				rootPart.AssemblyLinearVelocity = exitVelocity
			else
				-- ジャンプなし（カーブレール終端など）は速度を完全にリセット
				rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				
				-- 物理演算が適用された瞬間に飛ばされないよう、もう一度念のため直後にリセット
				task.defer(function()
					if rootPart.Parent then
						rootPart.Anchored = false
						rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					end
				end)
			end
		end
		
		if humanoid and state and state.originalWalkSpeed then
			humanoid.WalkSpeed = state.originalWalkSpeed
			humanoid.JumpPower = 50 
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true

			if shouldJump then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end

		-- 衝突判定を復元
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end
	
	-- クライアントに通知
	local GrindEnded = Net.E(Constants.Events.GrindEnded)
	if GrindEnded then
		GrindEnded:FireClient(player, exitVelocity, shouldJump)
	end
end

-- 次のレールを探す
local function findNextRail(currentRail, direction, previousRail)
	local rails = CollectionService:GetTagged(Constants.Tags.GrindRail)
	
	-- レールの端点を計算
	local railDir, railLength, _ = getRailInfo(currentRail)
	local sign = (direction:Dot(railDir) > 0) and 1 or -1
	local railEndPos = currentRail.Position + (railDir * sign * (railLength / 2))
	
	local bestNext = nil
	local bestDist = 5 -- 5 studs 以内

	for _, rail in ipairs(rails) do
		-- 現在のレールと前のレールを除外
		if rail ~= currentRail and rail ~= previousRail and rail:IsA("BasePart") then
			local nDir, nLen, _ = getRailInfo(rail)
			
			-- 線分上での最近接点
			local rel = railEndPos - rail.Position
			local projection = rel:Dot(nDir)
			local clampedProj = math.clamp(projection, -nLen/2, nLen/2)
			local nearestOnNext = rail.Position + (nDir * clampedProj)
			
			local dist = (railEndPos - nearestOnNext).Magnitude
			
			if dist < bestDist then
				bestDist = dist
				bestNext = rail
			end
		end
	end
	return bestNext
end

-- グラインド物理の更新
local function updateGrindPhysics(player, dt)
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
	
	local railDir, railLength, railThickness = getRailInfo(rail)
	local directionalRailDir = (state.worldDirection:Dot(railDir) > 0) and railDir or -railDir
	state.worldDirection = directionalRailDir
	
	local relativePos = rootPart.Position - rail.Position
	local projection = relativePos:Dot(railDir)
	
	local moveDistance = GrindConfig.GrindSpeed * dt
	local sign = (directionalRailDir:Dot(railDir) > 0) and 1 or -1
	local nextProjection = projection + (sign * moveDistance)
	
	-- レール端判定:3 studs の「粘り」を持たせる
	if math.abs(nextProjection) > (railLength / 2 + 1) then
		local nextRail = nil
		
		-- カーブレールの場合は専用の検索を使用
		if isCurvedRail(rail) and state.curvedRailDirection then
			local railType, currentSegment, maxSegment = getCurvedRailInfo(rail)
			print("[GrindService] Curved rail transition from segment:", currentSegment, "direction:", state.curvedRailDirection)
			
			nextRail = findNextCurvedSegment(rail, state.curvedRailDirection)
			
			-- 次のセグメントが見つからない場合は終了
			if not nextRail then
				local nextSegmentNum = currentSegment + state.curvedRailDirection
				print("[GrindService] Curved rail end - no next segment. Current:", currentSegment, "Next would be:", nextSegmentNum)
				
				-- カーブレール終了時はジャンプなし、速度をゼロに
				endGrind(player, "end_of_curved_rail", nil, false)
				return
			else
				print("[GrindService] Found next curved segment:", nextRail.Name)
			end
		else
			-- 通常のレールの場合は既存のロジック
			nextRail = findNextRail(rail, directionalRailDir, state.previousRail)
		end
		
		if nextRail then
			-- 前のレールを更新
			state.previousRail = rail
			state.rail = nextRail
			rail = nextRail
			local nDir, nLen, nThick = getRailInfo(rail)
			
			local nRel = rootPart.Position - rail.Position
			local nProj = nRel:Dot(nDir)
			
			state.worldDirection = (state.worldDirection:Dot(nDir) > 0) and nDir or -nDir
			local nSign = (state.worldDirection:Dot(nDir) > 0) and 1 or -1
			nextProjection = nProj + (nSign * moveDistance)
			
			railDir, railLength, railThickness = nDir, nLen, nThick
			directionalRailDir = state.worldDirection
			print("[GrindService] Seamless Switch:", rail.Name)
		elseif math.abs(nextProjection) > (railLength / 2 + 3) then -- 3 studs 完全に外れたら終了
			-- 通常のレールの終端処理(カーブレールは上で処理済み)
			if not isCurvedRail(rail) then
				local jumpVel = Vector3.new(0, GrindConfig.JumpOffUpwardForce, 0) + 
								directionalRailDir * GrindConfig.JumpOffForwardForce
				endGrind(player, "end_of_rail", jumpVel, true)
			end
			return
		end
	end
	
	local finalPointOnLine = rail.Position + (railDir * nextProjection)
	local targetY = finalPointOnLine.Y + (railThickness / 2) + 3.5
	local finalPos = Vector3.new(finalPointOnLine.X, targetY, finalPointOnLine.Z)
	
	rootPart.CFrame = CFrame.lookAt(finalPos, finalPos + state.worldDirection)
	rootPart.AssemblyLinearVelocity = Vector3.zero
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
	endGrind(player, "jump_off", nil, true)
end

-- メインループ（レール検出とグラインド物理）
local function onHeartbeat(dt)
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
				updateGrindPhysics(player, dt)
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
	local SkateboardGrindJump = Net.E(Constants.Events.SkateboardGrindJump)
	if SkateboardGrindJump then
		SkateboardGrindJump.OnServerEvent:Connect(function(player)
			handleGrindJump(player)
		end)
	end
	
	-- メインループ開始
	RunService.Heartbeat:Connect(onHeartbeat)
	
	-- プレイヤー退出時のクリーンアップ
	Players.PlayerRemoving:Connect(function(player)
		if player:GetAttribute(Constants.Attr.IsGrinding) then
			endGrind(player, "player_leaving")
		end
		playerGrindStates[player] = nil
	end)
end

return GrindService
