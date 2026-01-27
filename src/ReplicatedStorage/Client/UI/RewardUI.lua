-- RewardUI.lua
-- 報酬獲得時のポップアップ通知UI

local RewardUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- 設定
local POPUP_LIFETIME = 1.2
local FLOAT_HEIGHT = 80
local COLORS = {
	Positive = Color3.fromRGB(255, 230, 100), -- ゴールド
	Normal = Color3.fromRGB(255, 255, 255)
}

local _gui = nil
local function getGui()
	if _gui then return _gui end
	
	local pgui = player:WaitForChild("PlayerGui", 10)
	if not pgui then 
		warn("[RewardUI] PlayerGui not found after 10s")
		return nil 
	end
	
	_gui = pgui:FindFirstChild("RewardPopupGui")
	if not _gui then
		_gui = Instance.new("ScreenGui")
		_gui.Name = "RewardPopupGui"
		_gui.IgnoreGuiInset = true
		_gui.DisplayOrder = 100
		_gui.ResetOnSpawn = false
		_gui.Parent = pgui
	end
	return _gui
end

-- ポップアップの表示
function RewardUI.ShowReward(amount)
	if not amount or amount <= 0 then return end
	
	local gui = getGui()
	if not gui then return end
	
	-- コンテナ作成
	local container = Instance.new("Frame")
	container.Name = "RewardPopup"
	container.Size = UDim2.new(0, 200, 0, 50)
	container.Position = UDim2.new(0.5, 0, 0.6, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Parent = gui
	
	-- テキストラベル
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = string.format("+%d", amount)
	label.TextColor3 = COLORS.Positive
	label.TextSize = 40
	label.Parent = container
	
	-- アイコン
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 40, 0, 40)
	icon.Position = UDim2.new(0, -20, 0.5, 0)
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.BackgroundTransparency = 1
	icon.Text = "💰"
	icon.TextSize = 35
	icon.Parent = label
	
	-- ストローク
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	
	-- アニメーション
	container.Size = UDim2.new(0, 0, 0, 0)
	
	local showTween = TweenService:Create(container, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 200, 0, 50)
	})
	showTween:Play()
	
	task.delay(0.2, function()
		local floatTween = TweenService:Create(container, TweenInfo.new(POPUP_LIFETIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.6, -FLOAT_HEIGHT)
		})
		local fadeTween = TweenService:Create(label, TweenInfo.new(POPUP_LIFETIME, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			TextTransparency = 1
		})
		local iconFade = TweenService:Create(icon, TweenInfo.new(POPUP_LIFETIME, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			TextTransparency = 1
		})
		local strokeFade = TweenService:Create(stroke, TweenInfo.new(POPUP_LIFETIME, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Transparency = 1
		})
		
		floatTween:Play()
		fadeTween:Play()
		iconFade:Play()
		strokeFade:Play()
		
		floatTween.Completed:Connect(function()
			container:Destroy()
		end)
	end)
end

return RewardUI
