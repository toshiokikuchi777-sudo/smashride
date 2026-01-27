--// CanService.lua
--// 缶が潰れたときのサーバー処理：スコア加算 & リスポーン + ハンマー解除判定 + アビリティ

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local CanService = {}

-- GameConfig, Math
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local EffectMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Math"):WaitForChild("EffectMath"))
local ScoreMath  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Math"):WaitForChild("ScoreMath"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))

-- Remote Events (Unified via Net)
local RE_ScoreChanged = Net.E("ScoreChanged")
local RE_ScrapChanged = Net.E("ScrapChanged")
local RE_CansSmashed = Net.E("CansSmashed")
local RE_UnlockStateSync = Net.E("UnlockStateSync")
local RE_CrushCanVisual = Net.E("CrushCanVisual")
local RE_StageUp = Net.E("StageUp")
local RE_MultiplierVFX = Net.E("MultiplierVFX")
local RE_ShockwaveVFX = Net.E("ShockwaveVFX")
local RE_EffectStateSync = Net.E("EffectStateSync")
local RE_EquipHammerRequest = Net.E("EquipHammerRequest")
local RE_StageSync = Net.E("StageSync")
local RE_CanLocked = Net.E("CanLocked")

-- Legacy Remotes
local CanCrushedEvent = Net.E("CanCrushed")
local SetEquippedHammer = Net.E("SetEquippedHammer")
local RE_CanCrushResult = Net.E("CanCrushResult")

local function replyCrushResult(player, canModel, ok, reason)
	if not player then return end
	RE_CanCrushResult:FireClient(player, canModel, ok == true, tostring(reason or (ok and "OK" or "REJECT")))
end

----------------------------------------------------------------
-- 内部定数 / 状態管理
----------------------------------------------------------------
local playerScores = {}
local shockwaveCooldowns = {}
local playerCansSmashedCount = {} -- Track SMASHED count in memory (DataStore fallback)

local CRUSH_SHOW_TIME = 1.0
local RESPAWN_DELAY = 3.0

-- Server検証用定数
local MAX_HIT_DISTANCE = 16  -- studs（Client Raycast 16 に合わせる）

-- バースト制限
local BURST_WINDOW = 0.3
local BURST_LIMIT = 3

-- 距離ベースVFX同期用定数
local VFX_CRUSH_RADIUS = 120
local VFX_SHOCKWAVE_RADIUS = 180

-- バースト制限用State
local hitHistory = {}  -- [player] = {tick1, tick2, ...}

-- 前方宣言
local doShockwave

-- テンプレート取得
local CansTemplate = ServerStorage:FindFirstChild("Templates") and ServerStorage.Templates:FindFirstChild("Cans")
if not CansTemplate then
	CansTemplate = workspace:FindFirstChild("Cans")
end

----------------------------------------------------------------
-- 内部関数
----------------------------------------------------------------
local function getPlayerScore(player)
	if not playerScores[player] then
		playerScores[player] = {
			total = 0,
			last = "",
			red = 0,
			blue = 0,
			green = 0,
			purple = 0,
			yellow = 0
		}
	end
	return playerScores[player]
end

----------------------------------------------------------------
-- ユーティリティ / サービス取得 (Lazy Load)
----------------------------------------------------------------
local DataService = nil
local function getDataService()
	if not DataService then
		DataService = require(game:GetService("ServerScriptService").Services.DataService)
	end
	return DataService
end

local UnlockService = nil
local function getUnlockService()
	if not UnlockService then
		UnlockService = require(game:GetService("ServerScriptService").Services.UnlockService)
	end
	return UnlockService
end

local EffectState = nil
local function getEffectState()
	if not EffectState then
		EffectState = require(game:GetService("ServerScriptService").Services.EffectState)
	end
	return EffectState
end

-- 距離内プレイヤーにのみRemoteEvent送信
local function fireToNearbyPlayers(event, position, maxDistance, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local distance = (hrp.Position - position).Magnitude
			if distance <= maxDistance then
				event:FireClient(p, ...)
			end
		end
	end
end

-- [FIX] BoundingBox 最近点距離（倒れてても安定）
local function distanceToModelBBox(point: Vector3, model: Model): number
	local cf, size = model:GetBoundingBox()
	local localPoint = cf:PointToObjectSpace(point)
	local half = size * 0.5

	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)

	local closestWorld = cf:PointToWorldSpace(clamped)
	return (point - closestWorld).Magnitude
end

local PetEffectService = nil
local function getPetEffectService()
	if not PetEffectService then
		local ServerScriptService = game:GetService("ServerScriptService")
		PetEffectService = require(ServerScriptService.Services.PetEffectService)
	end
	return PetEffectService
end

local function pushScore(player)
	local scores = getPlayerScore(player)
	RE_ScoreChanged:FireClient(player, scores)
	RE_ScrapChanged:FireClient(player, scores.total)

	local DS = getDataService()
	local data = DS and DS.Get(player)

	local total = 0
	if playerCansSmashedCount[player] ~= nil then
		total = playerCansSmashedCount[player]
	elseif data then
		total = data.cansSmashedTotal or 0
	end

	RE_CansSmashed:FireClient(player, total)
	local stage, prev, nextReq = GameConfig.GetStageProgress(total)
	RE_StageSync:FireClient(player, stage, total, prev, nextReq)
end

local function syncUnlockState(player)
	local DS = getDataService()
	local data = DS.Get(player)
	local US = getUnlockService()
	if data and US then
		local payload = US.BuildSyncPayload(data)
		RE_UnlockStateSync:FireClient(player, payload)
	end
end

local function getCanColor(canName)
	if not canName then return nil end
	local upper = string.upper(canName)
	if string.find(upper, "RED") then return "RED"
	elseif string.find(upper, "BLUE") then return "BLUE"
	elseif string.find(upper, "GREEN") then return "GREEN"
	elseif string.find(upper, "PURPLE") then return "PURPLE"
	elseif string.find(upper, "YELLOW") then return "YELLOW"
	end
	return nil
end

local function calculatePoints(player, canColor)
	local hammerType = player:GetAttribute("EquippedHammer") or "NONE"
	local hammerConfig = GameConfig.Hammers and GameConfig.Hammers[hammerType]
	local canConfig = GameConfig.CanTypes and GameConfig.CanTypes[canColor]
	local basePoint = (canConfig and canConfig.point) or 1
	local hammerMult = (hammerConfig and hammerConfig.multipliers and canColor and hammerConfig.multipliers[canColor]) or 1.0

	local petMult = 1.0
	local PES = getPetEffectService()
	if PES then petMult = PES.getPetBonusMult(player) end

	local totalMult = EffectMath.CalcTotalMult(hammerMult, petMult)
	local finalPoint = ScoreMath.CalcHitGain(basePoint, totalMult)

	if hammerMult > 1 then
		RE_MultiplierVFX:FireClient(player, canColor, hammerMult, finalPoint)
	end

	return finalPoint
end

function CanService.addScrap(player, canName)
	local scores = getPlayerScore(player)
	local color = getCanColor(canName or "")
	local points = calculatePoints(player, color)

	scores.total = scores.total + points
	local colorLower = color and color:lower() or nil
	
	local DS = getDataService()
	local data = DS and DS.Get(player)

	if colorLower and scores[colorLower] ~= nil then
		scores[colorLower] = scores[colorLower] + 1
		-- DataService 側のデータも更新
		if data and data.smashedCounts then
			data.smashedCounts[colorLower] = scores[colorLower]
		end
	end
	scores.last = string.format("+%d (%s)", points, color or "?")
	pushScore(player)

	if DS and data then
		data.total = scores.total
		DS.MarkDirty(player)
	end
	return points
end

function CanService.SetTotalScore(player, value, lastText)
	local scores = getPlayerScore(player)
	scores.total = value or 0
	if lastText then scores.last = lastText end
	pushScore(player)
end

function CanService.AddScore(player, amount)
	local scores = getPlayerScore(player)
	scores.total = (scores.total or 0) + amount
	scores.last = string.format("+%d (BONUS)", amount)
	pushScore(player)

	local DS = getDataService()
	local data = DS and DS.Get(player)
	if DS and data then
		data.total = scores.total
		DS.MarkDirty(player)
	end
end

local function canSmashCan(player, canColor)
	local hammerType = player:GetAttribute("EquippedHammer")
	if not hammerType or hammerType == "NONE" then
		return false
	end

	local limit = GameConfig.HammerCanLimit[hammerType] or 0
	local index = Constants.CanColorIndex[canColor]
	return index and index <= limit
end

-- リスポーン処理（SMASHED更新含む）
local function initiateRespawn(canName, crushPivot, player)
	if player then
		playerCansSmashedCount[player] = (playerCansSmashedCount[player] or 0) + 1
		RE_CansSmashed:FireClient(player, playerCansSmashedCount[player])

		local DS = getDataService()
		if DS then
			local data = DS.Get(player)
			if data then
				data.cansSmashedTotal = playerCansSmashedCount[player]
				DS.MarkDirty(player)
				syncUnlockState(player)
			end
		end
	end

	task.delay(CRUSH_SHOW_TIME, function()
		task.delay(RESPAWN_DELAY, function()
			if not CansTemplate then
				warn("[CanService] CansTemplate is NIL during respawn!")
				return
			end

			local template = CansTemplate:FindFirstChild(canName)
			if not template then
				warn("[CanService] Template NOT found:", tostring(canName))
				return
			end

			local newCan = template:Clone()
			newCan.Name = canName

			for _, p in ipairs(newCan:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = false
					p.CanCollide = true
				end
			end

			local rot = CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
			local spawnPos = crushPivot.Position + Vector3.new(0, 2.0, 0)
			newCan:PivotTo(CFrame.new(spawnPos) * rot)

			local parentFolder = workspace:FindFirstChild("Cans")
			if parentFolder then
				newCan.Parent = parentFolder
			else
				warn("[CanService] Workspace.Cans folder not found!")
				newCan:Destroy()
			end
		end)
	end)
end

local function crushCan(canModel, player, isShockwave)
	if not canModel or not canModel.Parent then
		replyCrushResult(player, canModel, false, "INVALID")
		return 0
	end

	if canModel:GetAttribute("ServerHandled") then
		replyCrushResult(player, canModel, false, "ALREADY_HANDLED")
		return 0
	end

	local color = getCanColor(canModel.Name)
	if not canSmashCan(player, color) then
		RE_CanLocked:FireClient(player, canModel:GetPivot().Position, canModel)
		replyCrushResult(player, canModel, false, "LOCKED")
		return 0
	end

	canModel:SetAttribute("ServerHandled", true)

	local canName = canModel.Name
	local crushPivot = canModel:GetPivot()

	local points = CanService.addScrap(player, canName)

	fireToNearbyPlayers(RE_CrushCanVisual, crushPivot.Position, VFX_CRUSH_RADIUS, canModel, player)
	replyCrushResult(player, canModel, true, "OK")

	initiateRespawn(canName, crushPivot, player)

	if not isShockwave then
		local hammerType = player:GetAttribute("EquippedHammer") or "NONE"
		local hammerConfig = GameConfig.Hammers[hammerType]

		if hammerConfig then
			local ability = hammerConfig.ability
			local radius = hammerConfig.radius or 15
			local cooldown = hammerConfig.cooldown or 5

			if ability == "SMALL_SHOCKWAVE" then
				radius = 8
				cooldown = 3
			end

			if ability == "SHOCKWAVE" or ability == "HYBRID" or hammerType == "MASTER" or ability == "SMALL_SHOCKWAVE" then
				local lastUse = shockwaveCooldowns[player] or 0
				if (tick() - lastUse) >= cooldown then
					shockwaveCooldowns[player] = tick()
					task.spawn(function()
						doShockwave(player, crushPivot.Position, radius)
					end)
				end
			end
		end
	end

	task.delay(CRUSH_SHOW_TIME, function()
		if canModel.Parent then canModel:Destroy() end
	end)

	return points
end

doShockwave = function(player, centerPosition, radius)
	local cansFolder = workspace:FindFirstChild("Cans")
	if not cansFolder then return 0 end

	local hitBaseScores = {}
	local cansToCrush = {}

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = { cansFolder }

	local parts = workspace:GetPartBoundsInRadius(centerPosition, radius, params)
	local processedModels = {}

	for _, part in ipairs(parts) do
		local can = part:FindFirstAncestorWhichIsA("Model")
		if can and not processedModels[can] and not can:GetAttribute("ServerHandled") then
			processedModels[can] = true
			local color = getCanColor(can.Name)
			local canConfig = GameConfig.CanTypes[color]
			table.insert(hitBaseScores, (canConfig and canConfig.point) or 1)
			table.insert(cansToCrush, can)
		end
	end

	if #cansToCrush == 0 then return 0 end

	local hammerType = player:GetAttribute("EquippedHammer") or "NONE"

	local isBig = (hammerType == "MASTER" or hammerType == "HYBRID" or hammerType == "SHOCKWAVE")
	fireToNearbyPlayers(RE_ShockwaveVFX, centerPosition, VFX_SHOCKWAVE_RADIUS, centerPosition, radius, hammerType, isBig)

	local PES = getPetEffectService()
	local petMult = PES and PES.getPetBonusMult(player) or 1.0
	local totalMult = EffectMath.CalcTotalMult(1.0, petMult)
	local totalPoints = ScoreMath.CalcShockwaveGain(hitBaseScores, totalMult, "list")

	local scores = getPlayerScore(player) -- Moved this up to be accessible in the loop

	for _, can in ipairs(cansToCrush) do
		can:SetAttribute("ServerHandled", true)

		local canName = can.Name
		local color = getCanColor(canName)
		local colorLower = color and color:lower() or nil
		
		-- ショックウェーブでも各色カウントを増やす
		if colorLower and scores[colorLower] ~= nil then
			scores[colorLower] = scores[colorLower] + 1
		end

		local crushPivot = can:GetPivot()

		fireToNearbyPlayers(RE_CrushCanVisual, crushPivot.Position, VFX_CRUSH_RADIUS, can, player)
		initiateRespawn(canName, crushPivot, player)

		task.delay(CRUSH_SHOW_TIME, function()
			if can.Parent then can:Destroy() end
		end)
	end

	scores.total = scores.total + totalPoints
	scores.last = string.format("+%d (SHOCKWAVE)", totalPoints)
	
	local DS = getDataService()
	local data = DS and DS.Get(player)
	if data then
		data.total = scores.total
		-- 各色カウントもデータストアへ同期
		if data.smashedCounts then
			for _, col in ipairs({"red", "blue", "green", "purple", "yellow"}) do
				data.smashedCounts[col] = scores[col]
			end
		end
		DS.MarkDirty(player)
	end

	pushScore(player)

	-- ★ model=nil の結果通知（クライアントのpending解放用）
	replyCrushResult(player, nil, true, "SHOCKWAVE")

	return totalPoints
end

local function updateHammerVisual(player)
	local char = player.Character
	if not char then return end

	local hammerType = player:GetAttribute("EquippedHammer") or "NONE"

	for _, child in ipairs(char:GetChildren()) do
		if child.Name == "HammerVisual" or (child:IsA("Accessory") and string.find(child.Name, "Hammer_")) then
			child:Destroy()
		end
	end

	if hammerType == "NONE" or hammerType == "" then
		return
	end

	local modelsFolder = ReplicatedStorage:FindFirstChild("Models")
	local template = modelsFolder and modelsFolder:FindFirstChild("Hammer_" .. hammerType)

	if template then
		local hammerModel = template:Clone()
		hammerModel.Name = "HammerVisual"

		if hammerModel:IsA("Accessory") then
			local acc = hammerModel
			hammerModel = Instance.new("Model")
			hammerModel.Name = "HammerVisual"
			for _, c in ipairs(acc:GetChildren()) do
				if c:IsA("BasePart") then
					c.CanCollide = false
					c.CanTouch = false
				end
				c.Parent = hammerModel
			end
			acc:Destroy()
		end

		local handle = hammerModel:FindFirstChild("Handle") or hammerModel:FindFirstChildWhichIsA("BasePart", true)
		if handle then
			local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
			if rightHand then
				local oldMotor = rightHand:FindFirstChild("HammerMotor")
				if oldMotor then oldMotor:Destroy() end

				local motor = Instance.new("Motor6D")
				motor.Name = "HammerMotor"
				motor.Part0 = rightHand
				motor.Part1 = handle
				motor.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
				motor.Parent = rightHand

				hammerModel.Parent = char
			end
		end
	end
end

function CanService.RemoveHammer(player)
	local char = player.Character
	if not char then return end

	for _, child in ipairs(char:GetChildren()) do
		if child.Name == "HammerVisual" or (child:IsA("Accessory") and string.find(child.Name, "Hammer_")) then
			child:Destroy()
		end
	end

	local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if rightHand then
		local oldMotor = rightHand:FindFirstChild("HammerMotor")
		if oldMotor then oldMotor:Destroy() end
	end
end

local function initPlayer(player)
	if not player:GetAttribute("EquippedHammer") then
		player:SetAttribute("EquippedHammer", "NONE")
	end

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		updateHammerVisual(player)
	end)

	player:GetAttributeChangedSignal("EquippedHammer"):Connect(function()
		updateHammerVisual(player)
	end)

	if player.Character then
		task.spawn(updateHammerVisual, player)
	end

	task.spawn(function()
		local DS = getDataService()
		local data = nil

		local start = tick()
		while tick() - start < 5 do
			data = DS.Get(player)
			if data then break end
			task.wait(0.5)
		end

		local scores = getPlayerScore(player)

		if data then
			playerCansSmashedCount[player] = data.cansSmashedTotal or 0
			scores.total = tonumber(data.total or 0) or 0
			
			-- 各色カウントの復元
			if data.smashedCounts then
				for _, col in ipairs({"red", "blue", "green", "purple", "yellow"}) do
					scores[col] = tonumber(data.smashedCounts[col] or 0) or 0
				end
			end
			
			scores.last = "SYNC"
			pushScore(player)
			syncUnlockState(player)
		else
			playerCansSmashedCount[player] = 0
			scores.total = 0
			scores.last = "SYNC_TIMEOUT"
			pushScore(player)
			syncUnlockState(player)
		end
	end)
end

function CanService.Init()
	print("[CanService] Init (HitPos Distance Fix)")

	for _, player in ipairs(Players:GetPlayers()) do initPlayer(player) end
	Players.PlayerAdded:Connect(initPlayer)

	Players.PlayerRemoving:Connect(function(player)
		hitHistory[player] = nil
		playerScores[player] = nil
		shockwaveCooldowns[player] = nil
		playerCansSmashedCount[player] = nil
	end)

	-- ★★★ ここが重要：hitPos / hitPart を受け取る ★★★
	CanCrushedEvent.OnServerEvent:Connect(function(player, canModel, hitPos, hitPart)
		if not player or not player:IsA("Player") then return end

		-- V-1: canModel妥当性チェック
		if not canModel or not canModel:IsA("Model") then
			replyCrushResult(player, canModel, false, "INVALID_MODEL")
			return
		end

		local cansFolder = workspace:FindFirstChild("Cans")
		if not cansFolder or not canModel.Parent or not canModel:IsDescendantOf(cansFolder) then
			replyCrushResult(player, canModel, false, "INVALID_PARENT")
			return
		end

		if canModel:GetAttribute("ServerHandled") then
			replyCrushResult(player, canModel, false, "ALREADY_HANDLED")
			return
		end

		-- V-2: 距離チェック（hitPos → hitPart → BBox）
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			replyCrushResult(player, canModel, false, "NO_HRP")
			return
		end

		local origin = hrp.Position
		local distance

		if typeof(hitPos) == "Vector3" then
			distance = (origin - hitPos).Magnitude
		elseif typeof(hitPart) == "Instance"
			and hitPart:IsA("BasePart")
			and hitPart:IsDescendantOf(canModel) then
			distance = (origin - hitPart.Position).Magnitude
		else
			distance = distanceToModelBBox(origin, canModel)
		end

		if distance > MAX_HIT_DISTANCE then
			replyCrushResult(player, canModel, false, "TOO_FAR")
			return
		end

		-- V-3: バースト制限
		local now = tick()
		local history = hitHistory[player] or {}

		local newHistory = {}
		for _, t in ipairs(history) do
			if now - t < BURST_WINDOW then
				table.insert(newHistory, t)
			end
		end

		if #newHistory >= BURST_LIMIT then
			replyCrushResult(player, canModel, false, "BURST_LIMIT")
			return
		end

		table.insert(newHistory, now)
		hitHistory[player] = newHistory

		-- 検証OK
		crushCan(canModel, player, false)
	end)

	SetEquippedHammer.OnServerEvent:Connect(function(player, hammerType)
		hammerType = tostring(hammerType or "BASIC"):upper()
		if not GameConfig.Hammers[hammerType] then hammerType = "BASIC" end

		player:SetAttribute("EquippedHammer", hammerType)
		updateHammerVisual(player)
		RE_EquipHammerRequest:FireClient(player, hammerType)

		local DS = getDataService()
		local data = DS.Get(player)
		if data then
			data.effectRev = (data.effectRev or 0) + 1

			local hammerMult = 1.0
			local hammerConfig = GameConfig.Hammers[hammerType]
			if hammerConfig and hammerConfig.multipliers then
				hammerMult = hammerConfig.multipliers.NORMAL or 1.0
			end
			player:SetAttribute("HammerMult", hammerMult)

			local PES = getPetEffectService()
			local petBonusMult = PES and PES.getPetBonusMult(player) or 1.0

			local ES = getEffectState()
			local payload = ES.BuildPayload(data, hammerMult, petBonusMult)
			RE_EffectStateSync:FireClient(player, payload)
		end
	end)
end

return CanService
