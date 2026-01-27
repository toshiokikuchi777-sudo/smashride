-- ScoreController.client.lua
-- プレミアムカードデザイン & チャリンチャリン・カウントアニメーション実装版
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

local scoreChanged = Net.E("ScoreChanged")
local scrapChanged = Net.E("ScrapChanged")
local cansSmashed = Net.E("CansSmashed")

-- =========================
-- 🎨 プレミアムデザイン定数
-- =========================
local FONT = Enum.Font.FredokaOne
local STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local CARD_BG = Color3.fromRGB(30, 30, 35) -- ダークなカード背景
local CARD_BORDER = Color3.fromRGB(255, 255, 255)

-- =========================
-- 🏗 UI生成ロジック
-- =========================

-- 既存の UI 削除
local oldHud = pgui:FindFirstChild("MainHud_Modern")
if oldHud then oldHud:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHud_Modern"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = pgui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "ScorePanel"
mainFrame.Size = UDim2.new(0.35, 0, 0.6, 0)
mainFrame.AnchorPoint = Vector2.new(1, 0)
mainFrame.Position = UDim2.new(0.98, 0, 0.08, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.Parent = screenGui

-- 数値をフォーマット (1,234,567)
local function formatNum(v)
	return tostring(v or 0):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end

-- プレミアムなカード（枠）の作成
local function createScoreCard(name, title, icon, color, yPos)
	local container = Instance.new("Frame")
	container.Name = name .. "Card"
	container.Size = UDim2.new(0.95, 0, 0.12, 0)
	container.Position = UDim2.new(0.05, 0, yPos, 0)
	container.BackgroundColor3 = CARD_BG
	container.Parent = mainFrame
	
	Instance.new("UICorner", container).CornerRadius = UDim.new(0.4, 0)
	local stroke = Instance.new("UIStroke", container)
	stroke.Thickness = 2.5
	stroke.Color = color
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	
	-- タイトル & アイコン
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.4, 0, 0.6, 0)
	titleLbl.Position = UDim2.new(0.05, 0, 0.2, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = FONT
	titleLbl.Text = icon .. " " .. title
	titleLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	titleLbl.TextScaled = true
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = container
	Instance.new("UIStroke", titleLbl).Thickness = 1
	
	-- 数値ラベル (アニメーション対象)
	local valLbl = Instance.new("TextLabel")
	valLbl.Name = "ValueLabel"
	valLbl.Size = UDim2.new(0.5, 0, 0.75, 0)
	valLbl.Position = UDim2.new(0.45, 0, 0.125, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Font = FONT
	valLbl.Text = "0"
	valLbl.TextColor3 = color
	valLbl.TextScaled = true
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Parent = container
	valLbl:SetAttribute("CurrentValue", 0) -- 現在のアニメーション上の値を保持
	
	local valStroke = Instance.new("UIStroke", valLbl)
	valStroke.Thickness = 2
	valStroke.Color = STROKE_COLOR
	
	return valLbl
end

local scrapValue = createScoreCard("Scrap", "SCRAP", "💵", Color3.fromRGB(255, 230, 50), 0)
local smashedValue = createScoreCard("Smashed", "SMASHED", "🥫", Color3.fromRGB(255, 140, 40), 0.14)

-- 各色集計用のリスト
local listFrame = Instance.new("Frame")
listFrame.Name = "ColorList"
listFrame.Size = UDim2.new(0.6, 0, 0.6, 0)
listFrame.Position = UDim2.new(0.4, 0, 0.45, 0)
listFrame.BackgroundTransparency = 1
listFrame.Parent = mainFrame

local uiList = Instance.new("UIListLayout")
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0.01, 0)
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Right
uiList.Parent = listFrame

local function createColorLabel(name, color, order)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = UDim2.new(1, 0, 0.08, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = FONT
	lbl.Text = name .. ": 0"
	if typeof(color) == "Color3" then lbl.TextColor3 = color end
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Right
	lbl.LayoutOrder = order
	lbl.Parent = listFrame
	Instance.new("UIStroke", lbl).Thickness = 1.5
	return lbl
end

local redLabel    = createColorLabel("RED",    Color3.fromRGB(255, 80, 80),   1)
local blueLabel   = createColorLabel("BLUE",   Color3.fromRGB(80, 150, 255),  2)
local greenLabel  = createColorLabel("GREEN",  Color3.fromRGB(80, 255, 100),  3)
local purpleLabel = createColorLabel("PURPLE", Color3.fromRGB(200, 100, 255), 4)
local yellowLabel = createColorLabel("YELLOW", Color3.fromRGB(255, 255, 80),  5)
local lastLabel   = createColorLabel("LAST",   Color3.fromRGB(180, 180, 180), 6)
lastLabel.Text = "LAST: -"

-- =========================
-- 🔄 アニメーション & 更新ロジック
-- =========================

-- 数値を「チャリンチャリン」と加算させるアニメーション
local function animateValue(lbl, targetValue)
	local startValue = lbl:GetAttribute("CurrentValue") or 0
	print(string.format("[ScoreHUD] Animating %s: %s -> %s", lbl.Name, tostring(startValue), tostring(targetValue)))
	
	if startValue == targetValue then return end
	lbl:SetAttribute("CurrentValue", targetValue)
	
	-- 数値の変化を Tween 用の NumberValue を使って制御
	local valObj = Instance.new("NumberValue")
	valObj.Value = startValue
	
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local tween = TweenService:Create(valObj, tweenInfo, { Value = targetValue })
	
	-- ポヨヨン演出
	local container = lbl.Parent
	if container and container:IsA("Frame") then
		container:TweenSize(UDim2.new(1.05, 0, 0.13, 0), "Out", "Back", 0.1, true, function()
			container:TweenSize(UDim2.new(0.95, 0, 0.12, 0), "Out", "Quad", 0.2, true)
		end)
	end
	
	-- 毎フレーム数値を更新
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		if not lbl or not valObj then 
			if connection then connection:Disconnect() end
			return 
		end
		lbl.Text = formatNum(math.floor(valObj.Value))
	end)
	
	tween.Completed:Connect(function()
		if connection then connection:Disconnect() end
		if lbl then lbl.Text = formatNum(targetValue) end
		valObj:Destroy()
	end)
	
	tween:Play()
end

local function updateSimpleText(lbl, text, color)
	if lbl then
		lbl.Text = text
		if typeof(color) == "Color3" then lbl.TextColor3 = color end
	end
end

-- 初期状態の属性設定
scrapValue:SetAttribute("CurrentValue", 0)
smashedValue:SetAttribute("CurrentValue", 0)
scrapValue.Text = "0"
smashedValue.Text = "0"

-- イベント接続
scrapChanged.OnClientEvent:Connect(function(value)
	print("[ScoreHUD] Received ScrapChanged:", value)
	animateValue(scrapValue, value)
end)

scoreChanged.OnClientEvent:Connect(function(payload)
	print("[ScoreHUD] Received ScoreChanged payload")
	if typeof(payload) ~= "table" then return end
	animateValue(scrapValue, payload.total or 0)
	
	updateSimpleText(redLabel,    "RED: "    .. formatNum(payload.red))
	updateSimpleText(blueLabel,   "BLUE: "   .. formatNum(payload.blue))
	updateSimpleText(greenLabel,  "GREEN: "  .. formatNum(payload.green))
	updateSimpleText(purpleLabel, "PURPLE: " .. formatNum(payload.purple))
	updateSimpleText(yellowLabel, "YELLOW: " .. formatNum(payload.yellow))
	if payload.last then updateSimpleText(lastLabel, "LAST: " .. tostring(payload.last)) end
end)

cansSmashed.OnClientEvent:Connect(function(count)
	print("[ScoreHUD] Received CansSmashed:", count)
	animateValue(smashedValue, count)
end)

print("[ScoreController] Premium HUD Initialized with Debug Logs.")
