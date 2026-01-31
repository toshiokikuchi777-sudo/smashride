-- RewardUI.lua
-- 報酬獲得時のリッチなUI演出

local RewardUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

function RewardUI.Show(title, amount, color)
	local sg = Instance.new("ScreenGui")
	sg.Name = "RewardPopup"
	sg.ResetOnSpawn = false
	sg.Parent = PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(300, 100)
	frame.Position = UDim2.new(0.5, -150, 0.3, -50)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BackgroundTransparency = 1
	frame.Parent = sg

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 0.5)
	lbl.Text = title
	lbl.TextColor3 = color or Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.BackgroundTransparency = 1
	lbl.TextTransparency = 1
	lbl.Parent = frame

	local amtlbl = Instance.new("TextLabel")
	amtlbl.Size = UDim2.new(1, 0, 0.5, 0)
	amtlbl.Position = UDim2.new(0, 0, 0.5, 0)
	amtlbl.Text = "+" .. tostring(amount)
	amtlbl.TextColor3 = Color3.new(1, 0.9, 0)
	amtlbl.Font = Enum.Font.FredokaOne
	amtlbl.TextScaled = true
	amtlbl.BackgroundTransparency = 1
	amtlbl.TextTransparency = 1
	amtlbl.Parent = frame

	-- Fade In
	TweenService:Create(lbl, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	TweenService:Create(amtlbl, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()

	task.delay(2, function()
		TweenService:Create(lbl, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		TweenService:Create(amtlbl, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		local tw = TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
		tw:Play()
		tw.Completed:Wait()
		sg:Destroy()
	end)
end

-- ShowReward wrapper (CanControllerから呼ばれる)
function RewardUI.ShowReward(amount)
	RewardUI.Show("報酬獲得!", amount, Color3.fromRGB(255, 255, 100))
end

return RewardUI
