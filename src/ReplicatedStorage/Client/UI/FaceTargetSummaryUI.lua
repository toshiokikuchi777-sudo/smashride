-- FaceTargetSummaryUI.lua
-- 顔ターゲット破壊完了時の特別報酬サマリーUI

local FaceTargetSummaryUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- 設定
local DISPLAY_DURATION = 3.5
local COLORS = {
	Title = Color3.fromRGB(255, 230, 0), -- 鮮やかなイエロー
	TargetName = Color3.fromRGB(200, 200, 200),
	Reward = Color3.fromRGB(255, 255, 255)
}

local _gui = nil
local function getGui()
	if _gui then return _gui end
	
	local pgui = player:WaitForChild("PlayerGui", 10)
	if not pgui then 
		warn("[FaceTargetSummaryUI] PlayerGui not found after 10s")
		return nil 
	end
	
	_gui = pgui:FindFirstChild("FaceTargetSummaryGui")
	if not _gui then
		_gui = Instance.new("ScreenGui")
		_gui.Name = "FaceTargetSummaryGui"
		_gui.IgnoreGuiInset = true
		_gui.DisplayOrder = 110
		_gui.ResetOnSpawn = false
		_gui.Parent = pgui
	end
	return _gui
end

function FaceTargetSummaryUI.Show(targetName, totalReward)
	if not targetName or not totalReward then return end
	
	local gui = getGui()
	if not gui then return end
	
	-- コンテナ作成
	local container = Instance.new("Frame")
	container.Name = "SummaryContainer"
	container.Size = UDim2.new(0, 400, 0, 200)
	container.Position = UDim2.new(0.5, 0, 0.45, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Parent = gui
	
	-- タイトル: TARGET CLEARED!
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0.5, 0, 0.2, 0)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "TARGET CLEARED!"
	title.TextColor3 = COLORS.Title
	title.TextSize = 50
	title.Parent = container
	
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 4
	titleStroke.Color = Color3.new(0, 0, 0)
	titleStroke.Parent = title
	
	-- ターゲット名
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "TargetName"
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.new(0.5, 0, 0.45, 0)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = targetName
	nameLabel.TextColor3 = COLORS.TargetName
	nameLabel.TextSize = 24
	nameLabel.Parent = container
	
	-- 報酬額
	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Name = "Reward"
	rewardLabel.Size = UDim2.new(1, 0, 0, 50)
	rewardLabel.Position = UDim2.new(0.5, 0, 0.7, 0)
	rewardLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.Font = Enum.Font.GothamBlack
	rewardLabel.Text = string.format("REWARD: +%d", totalReward)
	rewardLabel.TextColor3 = COLORS.Reward
	rewardLabel.TextSize = 36
	rewardLabel.Parent = container
	
	local rewardStroke = Instance.new("UIStroke")
	rewardStroke.Thickness = 3
	rewardStroke.Color = Color3.new(0, 0, 0)
	rewardStroke.Parent = rewardLabel
	
	-- アニメーション
	container.Size = UDim2.new(0, 300, 0, 150)
	local showTween = TweenService:Create(container, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 400, 0, 200)
	})
	
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextLabel") then
			child.TextTransparency = 1
			TweenService:Create(child, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
			local s = child:FindFirstChildWhichIsA("UIStroke")
			if s then s.Transparency = 1; TweenService:Create(s, TweenInfo.new(0.5), {Transparency = 0}):Play() end
		end
	end
	showTween:Play()
	
	task.delay(DISPLAY_DURATION, function()
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.8), {TextTransparency = 1}):Play()
				local s = child:FindFirstChildWhichIsA("UIStroke")
				if s then TweenService:Create(s, TweenInfo.new(0.8), {Transparency = 1}):Play() end
			end
		end
		task.wait(0.8)
		container:Destroy()
	end)
end

return FaceTargetSummaryUI
