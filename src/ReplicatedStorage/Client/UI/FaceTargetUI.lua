-- FaceTargetUI.lua
-- ターゲット（顔・豚）のパワーゲージUI (BillboardGui) - 究極のプレミアムデザイン
-- POWER ゲージとしての復元版

local FaceTargetUI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)
local FaceTargetConfig = require(ReplicatedStorage.Shared.Config.FaceTargetConfig)

-- 内部レジストリ (targetId -> labels/frames)
local registry = {}

-- 初期化
function FaceTargetUI.Init()
	print("[FaceTargetUI] プレミアムパワーゲージ初期化")
	
	-- ダメージ通知の受信
	Net.On(Constants.Events.FaceTargetDamaged, function(data)
		FaceTargetUI.UpdateHealthBar(data.targetId, data.newHP)
	end)
	
	print("[FaceTargetUI] 初期化完了")
end

-- 内部描画更新用 (アニメーション含む)
function FaceTargetUI.RenderUpdate(gui, hp, max)
	if not gui or not gui.Parent then return end
	local main = gui:FindFirstChild("MainFrame")
	if not main then return end
	
	-- HP 0 の場合は即座に消す
	if hp <= 0 then
		gui.Enabled = false
		return
	end

	local barContainer = main:FindFirstChild("BarContainer")
	local fill = barContainer and barContainer:FindFirstChild("Fill")
	local label = main:FindFirstChild("PowerLabel")
	local uiScale = gui:FindFirstChildOfClass("UIScale")
	
	local ratio = math.clamp(hp / (max or 1), 0, 1)
	
	-- テキスト更新
	if label then
		label.Text = string.format("TARGET POWER: %d / %d", hp, max or 1)
	end
	
	-- ゲージ更新 (Tween)
	if fill then
		TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()
	end
	
	-- ヒット時のポップアニメーション
	if uiScale then
		uiScale.Scale = 1.2
		TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.0
		}):Play()
	end
end

-- HPバーの作成 (パワーゲージ仕様)
function FaceTargetUI.CreateHealthBar(model)
	if not model then return end
	if model:FindFirstChild("PowerGaugeGui") then return end
	
	-- 必要な属性を取得
	local targetId = model:GetAttribute(FaceTargetConfig.AttrTargetId)
	local maxHP = model:GetAttribute(FaceTargetConfig.AttrMaxHP) or 25
	
	if not targetId then
		task.delay(0.1, function()
			FaceTargetUI.CreateHealthBar(model)
		end)
		return
	end

	-- Billboard生成
	local gui = Instance.new("BillboardGui")
	gui.Name = "PowerGaugeGui"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 7, 0) -- 少し高めに
	gui.AlwaysOnTop = true
	gui.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	gui.Parent = model
	
	local uiScale = Instance.new("UIScale", gui)
	
	-- 背景・枠
	local main = Instance.new("Frame")
	main.Name = "MainFrame"
	main.Size = UDim2.fromScale(0.9, 0.6)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	main.BackgroundTransparency = 0.2
	main.BorderSizePixel = 0
	main.Parent = gui
	
	local corner = Instance.new("UICorner", main)
	corner.CornerRadius = UDim.new(0, 8)
	
	local stroke = Instance.new("UIStroke", main)
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	
	-- ゲージコンテナ
	local barContainer = Instance.new("Frame")
	barContainer.Name = "BarContainer"
	barContainer.Size = UDim2.new(0.9, 0, 0.3, 0)
	barContainer.Position = UDim2.new(0.5, 0, 0.75, 0)
	barContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	barContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barContainer.BorderSizePixel = 0
	barContainer.Parent = main
	
	Instance.new("UICorner", barContainer).CornerRadius = UDim.new(0, 4)
	
	-- ゲージ本体 (グラデーション)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = barContainer
	
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	
	local grad = Instance.new("UIGradient", fill)
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 0)), -- オレンジ
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50))   -- 赤
	})
	
	-- テキストラベル
	local label = Instance.new("TextLabel")
	label.Name = "PowerLabel"
	label.Size = UDim2.new(0.9, 0, 0.4, 0)
	label.Position = UDim2.new(0.5, 0, 0.3, 0)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "TARGET POWER: -- / --"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Parent = main
	
	local tStroke = Instance.new("UIStroke", label)
	tStroke.Thickness = 2
	tStroke.Color = Color3.new(0, 0, 0)
	
	registry[targetId] = gui
	
	-- 初回描画
	local currentHP = model:GetAttribute(FaceTargetConfig.AttrHP) or maxHP
	FaceTargetUI.RenderUpdate(gui, currentHP, maxHP)
end

function FaceTargetUI.UpdateHealthBar(targetId, newHP)
	local gui = registry[targetId]
	if not gui then return end
	
	local model = gui.Parent
	local maxHP = model and model:GetAttribute(FaceTargetConfig.AttrMaxHP) or 25
	
	FaceTargetUI.RenderUpdate(gui, newHP, maxHP)
end

return FaceTargetUI
