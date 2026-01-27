--// StarterPlayer/StarterPlayerScripts/Controllers/PromotionController.lua

local PromotionController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Net = require(ReplicatedStorage.Shared.Net)
local PromotionConfig = require(ReplicatedStorage.Shared.Config.PromotionConfig)
local RewardUI = require(ReplicatedStorage.Client.UI.RewardUI)
local MoneyVFX = require(ReplicatedStorage.Client.VFX.MoneyVFX)

local _rewardPromptGui = nil

local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")

function PromotionController.Init()
	-- サーバーからの報酬通知受信
	Net.On("RewardNotification", function(data)
		PromotionController.ShowRewardEffect(data)
	end)

	-- ProximityPrompt の監視
	ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
		if playerWhoTriggered ~= player then return end
		
		-- AttributeはPromptの親（Part）に設定されている
		local triggerPart = prompt.Parent
		if not triggerPart then return end
		
		local promoType = triggerPart:GetAttribute("PromotionType")
		if promoType == "FEEDBACK" then
			PromotionController.OpenFeedbackUI()
		elseif promoType == "COMMUNITY" then
			PromotionController.OpenCommunityPrompt()
		end
	end)

	print("[PromotionController] Init complete")
end

-- コミュニティ用：グループ参加ページを開く
function PromotionController.OpenCommunityPrompt()
	local groupId = PromotionConfig.CommunityReward.GroupId
	if groupId == 0 then
		warn("[PromotionController] GroupId is NOT SET in PromotionConfig")
		return
	end
	
	-- 外部リンク（グループページ）を開く
	local url = "https://www.roblox.com/groups/" .. groupId
	print("Opening Community URL:", url)
	-- 注意: GuiService:OpenBrowserWindow 等はRobloxの仕様により使用制限がある場合がありますが、
	-- 本来はリンクボタン等を用意するのが安全です。ここでは導線としてprint+説明を表示します。
	
	PromotionController.ShowMainNotification(PromotionConfig.CommunityReward.JoinPromptText)
end

-- 報酬獲得時の演出
function PromotionController.ShowRewardEffect(data)
	if data.type == "FEEDBACK" then
		RewardUI.ShowReward(data.amount)
		MoneyVFX.PlayCollectionEffect(player.Character and player.Character:GetPivot().Position or Vector3.new(0,0,0))
	elseif data.type == "COMMUNITY" then
		-- 特殊な告知UI（後述）を表示
		print("COMMUNITY REWARD:", data.message)
		PromotionController.ShowMainNotification(data.message)
	end
end

-- メイン通知UI (簡易版)
function PromotionController.ShowMainNotification(message)
	local sg = Instance.new("ScreenGui")
	sg.Name = "PromotionNotification"
	sg.Parent = playerGui
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.4, 0, 0.2, 0)
	frame.Position = UDim2.new(0.5, 0, -0.2, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.3
	frame.Parent = sg
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 24
	label.Font = Enum.Font.GothamBold
	label.TextWrapped = true
	label.Parent = frame
	
	-- アニメーション
	frame:TweenPosition(UDim2.new(0.5, 0, 0.2, 0), "Out", "Back", 0.5)
	
	task.delay(4, function()
		frame:TweenPosition(UDim2.new(0.5, 0, -0.2, 0), "In", "Quad", 0.5)
		task.wait(0.5)
		sg:Destroy()
	end)
end

-- フィードバック用UI表示
function PromotionController.OpenFeedbackUI()
	if _rewardPromptGui then _rewardPromptGui:Destroy() end
	
	-- サーバーに最新状況を問い合わせる（またはDataServiceから取得することを想定）
	-- ここでは簡易的に、既に受け取っているかのフラグを確認
	local Net = require(ReplicatedStorage.Shared.Net)
	
	local sg = Instance.new("ScreenGui")
	sg.Name = "RewardPromptGui"
	sg.Parent = playerGui
	_rewardPromptGui = sg
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 320, 0, 180)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.BorderSizePixel = 0
	frame.Parent = sg
	
	local corner = Instance.new("UICorner")
	corner.Parent = frame
	
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 3
	uiStroke.Color = Color3.fromRGB(255, 255, 255)
	uiStroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 80)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = PromotionConfig.FeedbackReward.PromptText
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.TextWrapped = true
	title.Parent = frame
	
	local yesBtn = Instance.new("TextButton")
	yesBtn.Size = UDim2.new(0.8, 0, 0, 50)
	yesBtn.Position = UDim2.new(0.5, 0, 0.75, 0)
	yesBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	yesBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	yesBtn.Text = PromotionConfig.FeedbackReward.YesButtonText
	yesBtn.TextColor3 = Color3.new(1, 1, 1)
	yesBtn.TextSize = 24
	yesBtn.Font = Enum.Font.GothamBold
	yesBtn.Parent = frame
	
	local bCorner = Instance.new("UICorner")
	bCorner.Parent = yesBtn

	-- 既に取得済みかチェック (Serverから受け取った Attribute 等を使う)
	local hasClaimed = player:GetAttribute("HasClaimedFeedback") == true
	if hasClaimed then
		yesBtn.Text = PromotionConfig.FeedbackReward.ClaimedText
		yesBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		yesBtn.AutoButtonColor = false
	end
	
	yesBtn.Activated:Connect(function()
		if player:GetAttribute("HasClaimedFeedback") == true then return end
		Net.Fire("ClaimFeedbackReward")
		sg:Destroy()
		_rewardPromptGui = nil
	end)
	
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(1, 0, 1, 0)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = ""
	closeBtn.ZIndex = 0
	closeBtn.Parent = sg
	closeBtn.Activated:Connect(function()
		sg:Destroy()
		_rewardPromptGui = nil
	end)
end

return PromotionController
