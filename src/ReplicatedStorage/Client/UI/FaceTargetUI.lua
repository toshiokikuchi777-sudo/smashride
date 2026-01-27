-- FaceTargetUI.lua
-- 顔ターゲットのHPゲージUI (BillboardGui) - プレミアムデザイン

local FaceTargetUI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Net = require(ReplicatedStorage.Shared.Net)
local FaceTargetConfig = require(ReplicatedStorage.Shared.Config.FaceTargetConfig)

-- 内部レジストリ (targetId -> billboard)
local registry = {}

-- 初期化
function FaceTargetUI.Init()
	print("[FaceTargetUI] 初期化開始")
	
	-- ダメージ通知の受信
	Net.On("FaceTargetDamaged", function(data)
		FaceTargetUI.UpdateHealthBar(data.targetId, data.newHP)
	end)
	
	print("[FaceTargetUI] 初期化完了")
end

-- 内部描画更新用
function FaceTargetUI.RenderUpdate(gui, hp, max)
	if not gui or not gui.Parent then return end
	local main = gui:FindFirstChild("Main")
	if not main then return end
	
	-- HP 0 の場合は即座に消す（Tween 待たない）
	if hp <= 0 then
		gui.Enabled = false
		return
	end

	local fill = main:FindFirstChild("Fill", true)
	local label = main:FindFirstChild("HPLabel")
	local ratio = math.clamp(hp / (max or 1), 0, 1)
	
	if label then
		label.Text = string.format("HP: %d / %d", hp, max or 1)
		if ratio < 0.3 then label.TextColor3 = Color3.fromRGB(255, 100, 100) else label.TextColor3 = Color3.fromRGB(255, 255, 255) end
	end
	
	if fill then
		TweenService:Create(fill, TweenInfo.new(0.3), {Size = UDim2.new(ratio, 0, 1, 0)}):Play()
	end
end

-- HPバーの作成
function FaceTargetUI.CreateHealthBar(model, maxHP)
	if not model then return end
	if model:FindFirstChild("HealthBarGui") then return end
	
	-- ターゲットIDを取得できるまで少し待つ
	local targetId = model:GetAttribute(FaceTargetConfig.AttrTargetId)
	if not targetId then
		task.delay(0.1, function()
			FaceTargetUI.CreateHealthBar(model, maxHP)
		end)
		return
	end

	-- 属性がない場合のデフォルト値
	local currentMaxHP = maxHP or model:GetAttribute(FaceTargetConfig.AttrMaxHP) or 5
	local currentHP = model:GetAttribute(FaceTargetConfig.AttrHP) or currentMaxHP
	
	print("[FaceTargetUI] Creating Health Bar for:", model.Name, "ID:", targetId, "HP:", currentHP, "/", currentMaxHP)
	
	-- パーツが見つかるまで最大2秒待機
	local adornee = nil
	local startTime = tick()
	while tick() - startTime < 2 do
		adornee = model.PrimaryPart or model:FindFirstChild("Head") or model:FindFirstChild("Face") or model:FindFirstChildWhichIsA("BasePart", true)
		if adornee then break end
		task.wait(0.2)
	end

	if not adornee then
		warn("[FaceTargetUI] No Adornee part found for model after wait:", model.Name)
		return
	end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBarGui"
	billboard.Size = UDim2.new(0, 140, 0, 30)
	billboard.Adornee = adornee
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.ResetOnSpawn = false
	
	-- 省略: フレーム構成ロジックは維持
	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.new(1, 0, 1, 0)
	main.BackgroundTransparency = 1
	main.Parent = billboard
	
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Position = UDim2.new(0, 0, 0.4, 0)
	bg.Size = UDim2.new(1, 0, 0.4, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BorderSizePixel = 0
	bg.Parent = main
	
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(255, 255, 255)
	bgStroke.Thickness = 1.5
	bgStroke.Transparency = 0.5
	bgStroke.Parent = bg
	
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 6)
	bgCorner.Parent = bg
	
	local fillPath = Instance.new("Frame")
	fillPath.Name = "FillPath"
	fillPath.Size = UDim2.new(1, 0, 1, 0)
	fillPath.BackgroundTransparency = 1
	fillPath.ClipsDescendants = true
	fillPath.Parent = bg
	
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(math.clamp(currentHP / currentMaxHP, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	fill.BorderSizePixel = 0
	fill.Parent = fillPath
	
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 50))
	})
	gradient.Parent = fill
	
	local fillCorner = bgCorner:Clone()
	fillCorner.Parent = fill
	
	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.Size = UDim2.new(1, 0, 0.4, 0)
	hpLabel.Position = UDim2.new(0, 0, 0, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpLabel.TextSize = 14
	hpLabel.Text = string.format("HP: %d / %d", currentHP, currentMaxHP)
	hpLabel.Parent = main
	
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Color3.fromRGB(0, 0, 0)
	textStroke.Parent = hpLabel
	
	-- レジストリに登録
	registry[targetId] = billboard
	
	-- クリーニング
	model.Destroying:Connect(function()
		registry[targetId] = nil
	end)

	-- 属性変更時の自動更新
	model:GetAttributeChangedSignal(FaceTargetConfig.AttrHP):Connect(function()
		local hp = model:GetAttribute(FaceTargetConfig.AttrHP) or 0
		local max = model:GetAttribute(FaceTargetConfig.AttrMaxHP) or currentMaxHP
		FaceTargetUI.RenderUpdate(billboard, hp, max)
	end)
	
	billboard.Parent = model
	return billboard
end

-- HPバーの更新 (高速: レジストリ参照)
function FaceTargetUI.UpdateHealthBar(targetId, newHP)
	local gui = registry[targetId]
	if gui and gui.Parent then
		local model = gui.Parent:IsA("Model") and gui.Parent or gui.Parent.Parent
		local maxHP = model:GetAttribute(FaceTargetConfig.AttrMaxHP) or 5
		FaceTargetUI.RenderUpdate(gui, newHP, maxHP)
	end
end

return FaceTargetUI
