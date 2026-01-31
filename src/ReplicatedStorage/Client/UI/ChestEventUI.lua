-- ReplicatedStorage/Client/UI/ChestEventUI.lua
-- 宝箱関連のUI演出（ポップアップ通知など）

local ChestEventUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local IS_MOBILE = UserInputService.TouchEnabled

-- 通知エリア設定
local screenGui = nil
local activePopups = 0
local popupBaseY = 0.7 -- 画面下の方
local popupXOffset = -30 -- 右端からのマージン

local function ensureGui()
	if screenGui then return end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ChestEventGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
end

-- 先着報酬などの通知を表示
function ChestEventUI.ShowNotification(title, amount)
	ensureGui()
	
	activePopups += 1
	local currentOffset = (activePopups - 1) * 70 -- 重ならないようにずらす
	
	local popup = Instance.new("Frame")
	popup.AnchorPoint = Vector2.new(1, 0) -- 右上を基準にする
	popup.Size = UDim2.new(0, 220, 0, 70)
	popup.Position = UDim2.new(1, 250, popupBaseY, -currentOffset) -- 画面外右（完全に隠れた状態）
	popup.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	popup.BackgroundTransparency = 0.2
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
	local targetPos = UDim2.new(1, popupXOffset, popupBaseY, -currentOffset) -- popupXOffset = -30
	
	local tweenIn = TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetPos
	})
	
	tweenIn:Play()
	
	-- 2.5秒後にスライドアウト
	task.delay(2.5, function()
		local tweenOut = TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 250, popupBaseY, -currentOffset),
			BackgroundTransparency = 1
		})
		
		tweenOut:Play()
		tweenOut.Completed:Wait()
		
		popup:Destroy()
		activePopups = math.max(0, activePopups - 1)
	end)
end

-- ShowRewardPopup wrapper (ChestControllerから呼ばれる)
function ChestEventUI.ShowRewardPopup(title, amount, chestType)
	ChestEventUI.ShowNotification(title, amount)
end

function ChestEventUI.Init()
	print("[ChestEventUI] Initialized")
end

return ChestEventUI
