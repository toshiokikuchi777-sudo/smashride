-- FaceTargetSummaryUI.lua
-- 顔ターゲット撃破時の集計結果を表示するUI - プレミアムデザイン

local FaceTargetSummaryUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local DISPLAY_DURATION = 4.0

local COLORS = {
	Background = Color3.fromRGB(0, 0, 0),
	Title = Color3.fromRGB(255, 255, 255),
	TargetName = Color3.fromRGB(255, 200, 100),
	Reward = Color3.fromRGB(100, 255, 100)
}

function FaceTargetSummaryUI.Show(targetName, totalReward)
	local sg = Instance.new("ScreenGui")
	sg.Name = "FaceTargetSummary"
	sg.ResetOnSpawn = false
	sg.Parent = PlayerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 400, 0, 200)
	container.Position = UDim2.new(0.5, 0, 0.4, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = COLORS.Background
	container.BackgroundTransparency = 0.3
	container.BorderSizePixel = 0
	container.Parent = sg
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20)
	corner.Parent = container
	
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = container

	-- タイトル
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.Position = UDim2.new(0.5, 0, 0.2, 0)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "TARGET SMASHED!"
	titleLabel.TextColor3 = COLORS.Title
	titleLabel.TextSize = 32
	titleLabel.Parent = container
	
	-- ターゲット名
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
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
