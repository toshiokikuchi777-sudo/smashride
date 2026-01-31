-- ServerScriptService/Services/SkateboardService.lua
-- スケボーアイテムのサーバー側処理（マルチボード対応版）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SkateboardService = {}

-- 設定読み込み
local SkateboardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SkateboardConfig"))
local SkateboardShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SkateboardShopConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))

-- プレイヤーごとのスケボー状態
local playerSkateboards = {}

-- DataService への参照（遅延取得）
local DataService

local function getDataService()
	if not DataService then
		DataService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataService"))
	end
	return DataService
end

-- スケボーモデルのテンプレート取得（modelId ベース）
local function getSkateboardTemplate(modelId)
	local templates = ServerStorage:FindFirstChild("Templates")
	local skateboards = templates and templates:FindFirstChild("Skateboards")
	
	-- Workspace からも探す（Argon 同期や手動移動の考慮）
	if not skateboards then
		skateboards = workspace:FindFirstChild("Skateboards")
	end
	
	if not skateboards then
		warn("[SkateboardService] Skateboards folder not found in ServerStorage.Templates or Workspace!")
		return nil
	end
	
	local skateboard = skateboards:FindFirstChild(modelId)
	if not skateboard then
		warn("[SkateboardService] Skateboard model not found:", modelId)
		return nil
	end
	
	return skateboard
end

-- プレイヤーの装備中スケボー設定を取得
local function getPlayerSkateboardConfig(player)
	local DS = getDataService()
	if not DS then return SkateboardShopConfig.Skateboards.BASIC end
	
	local data = DS.Get(player)
	if not data then return SkateboardShopConfig.Skateboards.BASIC end
	
	local equippedId = data.equippedSkateboard or "BASIC"
	return SkateboardShopConfig.Skateboards[equippedId] or SkateboardShopConfig.Skateboards.BASIC
end

-- スケボーを装備
function SkateboardService.EquipSkateboard(player, boardId)
	print("[SkateboardService] EquipSkateboard:", player.Name, "Board:", boardId or "Auto")
	
	-- 既に装備中の場合は一旦解除
	if playerSkateboards[player] and playerSkateboards[player].equipped then
		SkateboardService.UnequipSkateboard(player)
	end
	
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart then return false end
	
	-- プレイヤーの装備中スケボー設定を取得
	local config
	if boardId and boardId ~= "" then
		config = SkateboardShopConfig.Skateboards[boardId]
	else
		config = getPlayerSkateboardConfig(player)
	end

	if not config then 
		warn("[SkateboardService] Failed to determine board config")
		return false 
	end

	local template = getSkateboardTemplate(config.modelId)
	if not template then
		warn("[SkateboardService] Template not found for:", config.modelId)
		return false
	end
	
	local skateboard = template:Clone()
	local primary = skateboard.PrimaryPart or skateboard:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		warn("[SkateboardService] Model has no parts!")
		skateboard:Destroy()
		return false
	end
	skateboard.PrimaryPart = primary
	
	-- 足の裏に直接装着
	local leftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
	local rightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
	
	if not leftFoot or not rightFoot then
		warn("[SkateboardService] Feet not found!")
		skateboard:Destroy()
		return false
	end
	
	-- 足元に安定して配置するために HumanoidRootPart に固定し、ボードの向きを90度回転(長い方を前に)
	local skateboardCFrame = rootPart.CFrame * CFrame.new(0, -humanoid.HipHeight - 1.1, 0) * CFrame.Angles(0, math.rad(180), 0)
	
	-- Weld to rootPart (安定して水平を保つため)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = primary
	weld.Parent = skateboard
	
	skateboard:PivotTo(skateboardCFrame)
	skateboard.Parent = character
	
	-- Disable collision and unanchor
	for _, p in ipairs(skateboard:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
		end
	end
	
	-- 歩行アニメーションを無効化
	local animate = character:FindFirstChild("Animate")
	local animateEnabled = true
	if animate then
		animateEnabled = animate.Enabled
		animate.Enabled = false
		print("[SkateboardService] Disabled walk animations")
	end
	
	-- 既存のアニメーショントラックを停止
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in pairs(animator:GetPlayingAnimationTracks()) do
			if track.Name:lower():find("walk") or track.Name:lower():find("run") then
				track:Stop()
			end
		end
	end
	
	-- スケボーの能力を適用
	local baseSpeed = SkateboardShopConfig.BaseSkateboardSpeed
	local speed = baseSpeed * config.speedMultiplier
	local jumpPower = humanoid.JumpPower + config.jumpPowerBonus
	
	humanoid.HipHeight = humanoid.HipHeight + 1.2
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = jumpPower
	
	playerSkateboards[player] = {
		equipped = true,
		model = skateboard,
		originalHipHeight = humanoid.HipHeight - 1.2,
		originalJumpPower = humanoid.JumpPower - config.jumpPowerBonus,
		animateWasEnabled = animateEnabled
	}
	
	-- クライアントに状態を同期
	local SkateboardStateSync = Net.E(Constants.Events.SkateboardStateSync)
	if SkateboardStateSync then
		SkateboardStateSync:FireClient(player, true)
	end
	
	print("[SkateboardService] Equipped:", config.name, "Speed:", speed, "Jump:", jumpPower)
	return true
end

-- スケボーを解除
function SkateboardService.UnequipSkateboard(player)
	print("[SkateboardService] UnequipSkateboard:", player.Name) -- Debug print
	local state = playerSkateboards[player]
	if not state or not state.equipped then return false end
	
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	
	if state.model then state.model:Destroy() end
	if humanoid then
		if state.originalHipHeight then
			humanoid.HipHeight = state.originalHipHeight
		end
		if state.originalJumpPower then
			humanoid.JumpPower = state.originalJumpPower
		end
		humanoid.WalkSpeed = SkateboardShopConfig.NormalWalkSpeed
	end
	
	-- 歩行アニメーションを復元
	local animate = character and character:FindFirstChild("Animate")
	if animate and state.animateWasEnabled then
		animate.Enabled = true
		print("[SkateboardService] Re-enabled walk animations")
	end
	
	playerSkateboards[player] = { equipped = false, model = nil }
	
	-- クライアントに状態を同期
	local SkateboardStateSync = Net.E(Constants.Events.SkateboardStateSync)
	if SkateboardStateSync then
		SkateboardStateSync:FireClient(player, false)
	end
	
	return true
end

function SkateboardService.IsEquipped(player)
	local state = playerSkateboards[player]
	return state and state.equipped or false
end

function SkateboardService.ToggleSkateboard(player)
	if SkateboardService.IsEquipped(player) then
		-- スケボーが装備されている場合は解除
		return SkateboardService.UnequipSkateboard(player)
	else
		-- スケボーが装備されていない場合は、最後に装備していたスケボーを装備
		local DS = getDataService()
		if not DS then return false end
		
		local data = DS.Get(player)
		if not data then return false end
		
		local boardId = data.equippedSkateboard
		
		-- equippedSkateboardが"NONE"または空の場合は、BASICを装備
		if not boardId or boardId == "NONE" or boardId == "" then
			-- 所持しているスケボーの中から最初のものを選択（なければBASIC）
			if #data.ownedSkateboards > 0 then
				boardId = data.ownedSkateboards[1]
			else
				boardId = "BASIC"
			end
		end
		
		print("[SkateboardService] Auto-equipping skateboard:", boardId)
		return SkateboardService.EquipSkateboard(player, boardId)
	end
end

-- スケートボードを削除（装備解除用）
function SkateboardService.RemoveSkateboard(player)
	local state = playerSkateboards[player]
	if state and state.model then
		state.model:Destroy()
		state.model = nil
		state.equipped = false
		return true
	end
	return false
end

function SkateboardService.Init()
	print("[SkateboardService] Init (Multi-board support)")
	local ToggleSkateboardEvent = Net.E(Constants.Events.ToggleSkateboard)
	local SkateboardStateSync = Net.E(Constants.Events.SkateboardStateSync)
	
	ToggleSkateboardEvent.OnServerEvent:Connect(function(p)
		local success = SkateboardService.ToggleSkateboard(p)
		if success then
			SkateboardStateSync:FireClient(p, SkateboardService.IsEquipped(p))
		end
	end)
	
	Players.PlayerRemoving:Connect(function(p) playerSkateboards[p] = nil end)
end

return SkateboardService
