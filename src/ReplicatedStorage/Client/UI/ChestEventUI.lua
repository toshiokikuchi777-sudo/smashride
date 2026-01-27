-- ChestEventUI.lua
-- イベントカウントダウンUI、報酬ポップアップ (スマホ対応)

local ChestEventUI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local ChestConfig = require(ReplicatedStorage.Shared.Config.ChestConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI要素
local screenGui = nil
local countdownFrame = nil
local countdownLabel = nil
local eventTitleLabel = nil

-- ポップアップ管理用
local activePopups = 0
local MAX_POPUPS = 5

-- デバイス判定 (簡易)
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- 設定値 (レスポンシブ用)
local countdownSize = IS_MOBILE and UDim2.new(0, 220, 0, 60) or UDim2.new(0, 300, 0, 80)
local countdownPos = IS_MOBILE and UDim2.new(0.5, -110, 0, -25) or UDim2.new(0.5, -150, 0, -30)
local popupSize = IS_MOBILE and UDim2.new(0, 180, 0, 60) or UDim2.new(0, 240, 0, 80)
local popupXOffset = IS_MOBILE and -200 or -260
local popupBaseY = IS_MOBILE and 0.55 or 0.75 -- スマホはジャンプボタン回避のため少し上
local popupHeight = IS_MOBILE and 70 or 90

-- 初期化
function ChestEventUI.Init()
	print("[ChestEventUI] 初期化開始 (Mobile=" .. tostring(IS_MOBILE) .. ")")
	
	-- ScreenGui作成
	ChestEventUI.CreateUI()
	
	-- Remote受信
	Net.On("EventStateSync", ChestEventUI.OnEventStateSync)
	
	print("[ChestEventUI] 初期化完了")
end

-- UI作成
function ChestEventUI.CreateUI()
	-- ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ChestEventUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	
	-- カウントダウンフレーム(上部中央)
	countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "CountdownFrame"
	countdownFrame.Size = countdownSize
	countdownFrame.Position = countdownPos
	countdownFrame.BackgroundTransparency = 1
	countdownFrame.BorderSizePixel = 0
	countdownFrame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = countdownFrame
	
	-- イベントタイトル
	eventTitleLabel = Instance.new("TextLabel")
	eventTitleLabel.Name = "EventTitle"
	eventTitleLabel.Size = UDim2.new(1, 0, 0, IS_MOBILE and 25 or 30)
	eventTitleLabel.Position = UDim2.new(0, 0, 0, 5)
	eventTitleLabel.BackgroundTransparency = 1
	eventTitleLabel.Text = "次のイベントまで"
	eventTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	eventTitleLabel.TextSize = IS_MOBILE and 14 or 18
	eventTitleLabel.Font = Enum.Font.GothamBold
	eventTitleLabel.Parent = countdownFrame
	
	-- イベントタイトルに縁取りを追加
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 3
	titleStroke.Parent = eventTitleLabel
	
	-- カウントダウンラベル
	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.Size = UDim2.new(1, 0, 0, IS_MOBILE and 30 or 40)
	countdownLabel.Position = UDim2.new(0, 0, 0, IS_MOBILE and 18 or 22)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = "00:00:00"
	countdownLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	countdownLabel.TextSize = IS_MOBILE and 22 or 28
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.Parent = countdownFrame
	
	-- カウントダウンラベルに縁取りを追加
	local countdownStroke = Instance.new("UIStroke")
	countdownStroke.Color = Color3.fromRGB(0, 0, 0)
	countdownStroke.Thickness = 4
	countdownStroke.Parent = countdownLabel
end

-- EventStateSync受信
function ChestEventUI.OnEventStateSync(state)
	local eventId = state.eventId
	local isActive = state.isActive
	local event = EventConfig.Events[eventId]
	if not event then return end
	
	if isActive then
		-- イベント中
		local remainingTime = state.remainingTime or 0
		
		eventTitleLabel.Text = event.ui.title
		eventTitleLabel.TextColor3 = event.ui.color
		countdownLabel.Text = ChestEventUI.FormatTime(remainingTime)
		countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- 白にして視認性を高める
		
		-- 点滅アニメーション
		ChestEventUI.StartBlinkAnimation()
	else
		-- 待機中
		local timeUntilNext = state.timeUntilNext or 0
		
		eventTitleLabel.Text = "次: " .. event.displayName
		eventTitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		countdownLabel.Text = ChestEventUI.FormatTime(timeUntilNext)
		countdownLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		
		-- 点滅停止
		ChestEventUI.StopBlinkAnimation()
	end
end

-- 時間をフォーマット(HH:MM:SS)
function ChestEventUI.FormatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- 点滅アニメーション開始
function ChestEventUI.StartBlinkAnimation()
	-- 既存のアニメーションを停止
	ChestEventUI.StopBlinkAnimation()
	
	-- 点滅ループ
	ChestEventUI.blinkLoop = task.spawn(function()
		while true do
			local tween = TweenService:Create(countdownLabel, TweenInfo.new(0.5), {TextTransparency = 0.5})
			tween:Play()
			tween.Completed:Wait()
			
			local tween2 = TweenService:Create(countdownLabel, TweenInfo.new(0.5), {TextTransparency = 0})
			tween2:Play()
			tween2.Completed:Wait()
		end
	end)
end

-- 点滅アニメーション停止
function ChestEventUI.StopBlinkAnimation()
	if ChestEventUI.blinkLoop then
		task.cancel(ChestEventUI.blinkLoop)
		ChestEventUI.blinkLoop = nil
	end
	countdownLabel.TextTransparency = 0
end

-- 報酬ポップアップ表示
function ChestEventUI.ShowRewardPopup(title, amount, chestType)
	local chestData = ChestConfig.ChestTypes[chestType]
	
	-- スタック制限
	if activePopups >= MAX_POPUPS then
		return
	end
	
	activePopups = activePopups + 1
	local currentOffset = (activePopups - 1) * popupHeight
	
	-- ポップアップフレーム (右下付近)
	local popup = Instance.new("Frame")
	popup.Name = "RewardPopup"
	popup.Size = popupSize
	-- 初期位置 (画面外右側)
	popup.Position = UDim2.new(1, 0, popupBaseY, -currentOffset)
	popup.BackgroundColor3 = chestData.color
	popup.BackgroundTransparency = 0.2
	popup.BorderSizePixel = 0
	popup.ZIndex = 10
	popup.Active = false -- クリック透過
	popup.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = popup
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = popup
	
	-- タイトル (先着報酬！など)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
	titleLabel.Position = UDim2.new(0, 0, 0.1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = IS_MOBILE and 14 or 18
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Active = false -- 透過
	titleLabel.Parent = popup
	
	-- 報酬額
	local amountLabel = Instance.new("TextLabel")
	amountLabel.Size = UDim2.new(1, 0, 0.5, 0)
	amountLabel.Position = UDim2.new(0, 0, 0.45, 0)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = "+" .. tostring(amount) .. " スクラップ"
	amountLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	amountLabel.TextSize = IS_MOBILE and 18 or 22
	amountLabel.Font = Enum.Font.GothamBold
	amountLabel.Active = false -- 透過
	amountLabel.Parent = popup
	
	-- アニメーション: スライドイン (右から左)
	local targetPos = UDim2.new(1, popupXOffset, popupBaseY, -currentOffset)
	
	local tweenIn = TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetPos
	})
	
	tweenIn:Play()
	
	-- 2.5秒後にスライドアウト
	task.delay(2.5, function()
		local tweenOut = TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 0, popupBaseY, -currentOffset),
			BackgroundTransparency = 1
		})
		
		tweenOut:Play()
		tweenOut.Completed:Wait()
		
		popup:Destroy()
		activePopups = math.max(0, activePopups - 1)
	end)
end

return ChestEventUI
