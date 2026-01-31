-- ServerScriptService/SetupFeedbackPrompt.server.lua
-- フィードバック報酬用のProximityPromptを設置

local workspace = game:GetService("Workspace")

-- フィードバックプロンプトの設置場所を探す
local feedbackTrigger = workspace:FindFirstChild("FeedbackTrigger")

if not feedbackTrigger then
	warn("[SetupFeedbackPrompt] FeedbackTrigger not found in Workspace. Creating at default position...")
	
	-- デフォルト位置にPartを作成
	feedbackTrigger = Instance.new("Part")
	feedbackTrigger.Name = "FeedbackTrigger"
	feedbackTrigger.Size = Vector3.new(4, 6, 4)
	feedbackTrigger.Position = Vector3.new(0, 3, -30) -- スポーン地点の近く
	feedbackTrigger.Anchored = true
	feedbackTrigger.CanCollide = false
	feedbackTrigger.Transparency = 0.5
	feedbackTrigger.BrickColor = BrickColor.new("Bright blue")
	feedbackTrigger.Material = Enum.Material.Neon
	feedbackTrigger.Parent = workspace
	
	-- 目立つようにする
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.Parent = feedbackTrigger
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "👍 いいね報酬"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
end

-- ProximityPromptが既に存在するか確認
local existingPrompt = feedbackTrigger:FindFirstChildOfClass("ProximityPrompt")
if existingPrompt then
	print("[SetupFeedbackPrompt] ProximityPrompt already exists")
else
	-- ProximityPromptを作成
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "いいね報酬を受け取る"
	prompt.ObjectText = "フィードバック"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = feedbackTrigger
	
	print("[SetupFeedbackPrompt] ProximityPrompt created")
end

-- Attributeを設定
feedbackTrigger:SetAttribute("PromotionType", "FEEDBACK")

print("[SetupFeedbackPrompt] Feedback trigger setup complete at", feedbackTrigger.Position)
