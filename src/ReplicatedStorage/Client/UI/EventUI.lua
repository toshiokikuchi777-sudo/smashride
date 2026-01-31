-- ReplicatedStorage/Client/UI/EventUI.lua
-- イベントカウントダウンと通知表示 - Cyber Edition
local EventUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

local mainGui = nil
local countdownFrame = nil
local bannerFrame = nil

local FONT_REGULAR = Enum.Font.FredokaOne
local FONT_DIGITAL = Enum.Font.RobotoMono -- サイバー感じの等幅フォント

-- 時間を 00:00 形式に変換
local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", mins, secs)
end

local function ensureGui()
	if mainGui then return end
	mainGui = Instance.new("ScreenGui")
	mainGui.Name = "EventHud"
	mainGui.ResetOnSpawn = false
	mainGui.DisplayOrder = 10
	mainGui.Parent = pgui

	-- カウントダウン用フレーム (上部中央)
	countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "CountdownFrame"
	countdownFrame.Size = UDim2.new(0, 240, 0, 60)
	countdownFrame.Position = UDim2.new(0.5, 0, 0, 15)
	countdownFrame.AnchorPoint = Vector2.new(0.5, 0)
	countdownFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20) -- 深い紺
	countdownFrame.BackgroundTransparency = 0.3
	countdownFrame.BorderSizePixel = 0
	countdownFrame.Parent = mainGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = countdownFrame

	-- サイバー外枠 (ネオン)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 255, 255) -- シアンネオン
	stroke.Transparency = 0.2
	stroke.Parent = countdownFrame

	-- タイトルラベル (EVENT / NEXT)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
	titleLabel.Position = UDim2.new(0, 0, 0.1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = FONT_REGULAR
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	titleLabel.Text = "SYSTEM INITIALIZED"
	titleLabel.Parent = countdownFrame

	-- メインタイマーラベル
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0.6, 0)
	label.Position = UDim2.new(0, 0, 0.4, 0)
	label.BackgroundTransparency = 1
	label.Font = FONT_DIGITAL
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 28
	label.Text = "00:00"
	label.Parent = countdownFrame

	local tStroke = Instance.new("UIStroke")
	tStroke.Thickness = 1.5
	tStroke.Color = Color3.fromRGB(0, 150, 255)
	tStroke.Parent = label

	-- バナー演出用フレーム
	bannerFrame = Instance.new("Frame")
	bannerFrame.Name = "BannerFrame"
	bannerFrame.Size = UDim2.new(1, 0, 0.2, 0)
	bannerFrame.Position = UDim2.new(0, 0, 0.25, 0)
	bannerFrame.BackgroundTransparency = 1
	bannerFrame.Visible = false
	bannerFrame.Parent = mainGui
end

function EventUI.Update(state)
	ensureGui()
	if not state then return end

	local label = countdownFrame.Label
	local titleLabel = countdownFrame.TitleLabel
	local outerStroke = countdownFrame:FindFirstChildOfClass("UIStroke")
	
	if state.isActive then
		local config = EventConfig.Events[state.eventId]
		local name = (config and config.displayName or state.eventId):upper()
		
		titleLabel.Text = "🔴 LIVE EVENT: " .. name
		titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		
		label.Text = formatTime(state.remainingTime or 0)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		
		if outerStroke then outerStroke.Color = Color3.fromRGB(255, 50, 50) end
	else
		local config = EventConfig.Events[state.eventId]
		local name = (config and config.displayName or state.eventId):upper()
		
		titleLabel.Text = "⏳ NEXT EVENT: " .. name
		titleLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
		
		label.Text = formatTime(state.timeUntilNext or 0)
		label.TextColor3 = Color3.fromRGB(150, 255, 255)
		
		if outerStroke then outerStroke.Color = Color3.fromRGB(0, 255, 255) end
	end
end

function EventUI.ShowBanner(eventId)
	ensureGui()
	local config = EventConfig.Events[eventId]
	if not config or not config.ui then return end

	bannerFrame:ClearAllChildren()
	bannerFrame.Visible = true

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.6, 0)
	title.BackgroundTransparency = 1
	title.Font = FONT_REGULAR
	title.Text = config.ui.title
	title.TextColor3 = config.ui.color or Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Position = UDim2.new(0, 0, -0.5, 0)
	title.Parent = bannerFrame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = title

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0.3, 0)
	subtitle.Position = UDim2.new(0, 0, 0.6, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = FONT_REGULAR
	subtitle.Text = config.ui.subtitle
	subtitle.TextColor3 = Color3.new(1, 1, 1)
	subtitle.TextScaled = true
	subtitle.TextTransparency = 1
	subtitle.Parent = bannerFrame

	local sStroke = stroke:Clone()
	sStroke.Thickness = 2
	sStroke.Parent = subtitle

	-- アニメーション
	TweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Position = UDim2.new(0, 0, 0.1, 0)}):Play()
	task.delay(0.3, function()
		TweenService:Create(subtitle, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	end)

	task.delay(4, function()
		TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		TweenService:Create(subtitle, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		task.wait(0.6)
		if bannerFrame:FindFirstChild("TextLabel") == title then -- 別のバナーが開始されていなければ非表示
			bannerFrame.Visible = false
		end
	end)
end

function EventUI.Init()
	ensureGui()
	print("[EventUI] Cyber Init Completed")
end

return EventUI
