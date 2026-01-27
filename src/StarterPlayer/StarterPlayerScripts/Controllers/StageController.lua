--// StageController.lua
--// レベルのUI表示、プログレスバー、レベルアップ演出を管理
--// (完全コード管理版)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local StageSync = Net.E("StageSync")

local StageController = {}

-- 🎨 デザイン定数 (ScoreControllerと統一)
local FONT = Enum.Font.FredokaOne
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local BAR_BG_COLOR = Color3.fromRGB(40, 40, 40)
local BAR_FILL_COLOR = Color3.fromRGB(255, 200, 50)

-- 🏗 UI参照/生成変数
local screenGui = nil
local stageFrame = nil
local effectLayer = nil
local barFill = nil
local levelLabel = nil
local progressLabel = nil

local lastStage = nil
local activeEffectCount = 0

-- UI作成ユーティリティ
local function createLabel(name, text, size, pos, parent)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Font = FONT
	lbl.Text = text
	lbl.TextColor3 = TEXT_COLOR
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = STROKE_COLOR
	stroke.Parent = lbl

	return lbl
end

-- =========================
-- 🏗 UI構築ロジック
-- =========================
local function setupUI()
	-- 既存の UI 削除
	local old1 = pgui:FindFirstChild("StageGui")
	if old1 then old1:Destroy() end
	local old2 = pgui:FindFirstChild("MainHud_Level")
	if old2 then old2:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHud_Level"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = pgui

	-- エフェクトレイヤー (最前面)
	effectLayer = Instance.new("Frame")
	effectLayer.Name = "EffectLayer"
	effectLayer.Size = UDim2.new(1, 0, 1, 0)
	effectLayer.BackgroundTransparency = 1
	effectLayer.ZIndex = 100
	effectLayer.Visible = false
	effectLayer.Parent = screenGui

	-- メインフレーム (左上)
	stageFrame = Instance.new("Frame")
	stageFrame.Name = "LevelFrame"
	stageFrame.Size = UDim2.new(0.2, 0, 0.12, 0)
	stageFrame.Position = UDim2.new(0.02, 0, 0.12, 0) -- 下に下げてアイコンとの被りを解消
	stageFrame.BackgroundTransparency = 1
	stageFrame.Parent = screenGui

	levelLabel = createLabel("LevelLabel", "LEVEL: 1", UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0, 0), stageFrame)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- プログレスバー背景
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(0.9, 0, 0.25, 0)
	barBg.Position = UDim2.new(0, 0, 0.45, 0)
	barBg.BackgroundColor3 = BAR_BG_COLOR
	barBg.BorderSizePixel = 0
	barBg.Parent = stageFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = barBg

	-- プログレスバー本体
	barFill = Instance.new("Frame")
	barFill.Name = "Bar"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = BAR_FILL_COLOR
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local cornerFill = corner:Clone()
	cornerFill.Parent = barFill

	progressLabel = createLabel("ProgressLabel", "0 / 0", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0, 0, 0.75, 0), stageFrame)
	progressLabel.TextSize = 14
	progressLabel.TextXAlignment = Enum.TextXAlignment.Center

	print("[StageController] Programmatic UI Initialized (LEFT SIDE)")
end

-- 派手な演出
local function playStageUpFX()
	local cam = workspace.CurrentCamera
	if not cam or not effectLayer then return end

	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.7
	flash.BorderSizePixel = 0
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.ZIndex = 1001
	flash.Parent = effectLayer

	TweenService:Create(flash, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
	Debris:AddItem(flash, 1.5)

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0.5, 0, 0.3, 0)
	ring.Size = UDim2.new(0, 20, 0, 20)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 1002
	ring.Parent = effectLayer

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 10
	stroke.Color = Color3.fromRGB(255, 230, 120)
	stroke.Parent = ring

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring

	TweenService:Create(ring, TweenInfo.new(1.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 600, 0, 600)
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1
	}):Play()
	Debris:AddItem(ring, 2.0)
end

-- ステージアップ演出
local function playLevelUpEffect(newLevel)
	if not effectLayer then return end
	
	activeEffectCount += 1
	effectLayer.Visible = true
	
	playStageUpFX()
	
	local sound = ReplicatedStorage:FindFirstChild("StageUpSound", true)
	if sound then sound:Play() end

	local pop = createLabel("LevelUpPop", "🎉 LEVEL UP! " .. tostring(newLevel) .. " 🎉", UDim2.new(0, 800, 0, 250), UDim2.new(0.5, 0, 0.3, 0), effectLayer)
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.ZIndex = 1003
	pop.TextTransparency = 1
	pop.Size = UDim2.new(0, 400, 0, 150)

	TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		Size = UDim2.new(0, 800, 0, 250)
	}):Play()

	task.delay(3, function()
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
		Debris:AddItem(pop, 1)
		task.wait(1)
		activeEffectCount -= 1
		if activeEffectCount <= 0 then
			activeEffectCount = 0
			effectLayer.Visible = false
		end
	end)
end

-- 初期化
function StageController.Init()
	setupUI()

	StageSync.OnClientEvent:Connect(function(stage, totalSmashed, prevReq, nextReq)
		if not stageFrame then return end
		
		stage = tonumber(stage) or 1
		totalSmashed = tonumber(totalSmashed) or 0
		prevReq = tonumber(prevReq) or 0
		nextReq = nextReq ~= nil and tonumber(nextReq) or nil

		-- UI更新
		if levelLabel then
			levelLabel.Text = "LEVEL: " .. tostring(stage)
		end

		if nextReq and barFill and progressLabel then
			local denom = math.max(nextReq - prevReq, 1)
			local t = math.clamp((totalSmashed - prevReq) / denom, 0, 1)
			
			TweenService:Create(barFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(t, 0, 1, 0)
			}):Play()
			
			progressLabel.Text = string.format("%d / %d", totalSmashed, nextReq)
		elseif barFill and progressLabel then
			barFill.Size = UDim2.new(1, 0, 1, 0)
			progressLabel.Text = "MAX LEVEL"
		end

		if lastStage and stage > lastStage then
			playLevelUpEffect(stage)
		end
		lastStage = stage
	end)
	
	print("[StageController] Booted & Initialized.")
end

return StageController
