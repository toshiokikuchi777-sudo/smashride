-- StarterPlayer/StarterPlayerScripts/Controllers/SkateboardShopController.lua
-- スケボーショップのクライアント側処理

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local SkateboardShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SkateboardShopConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))

local SkateboardShopController = {}

-- UI参照
local shopFrame
local shopButton
local boardCards = {}
local selectedBoardId = nil

-- 詳細パネルのパーツ参照
local detailPanel
local detailIcon
local detailName
local detailSpeed
local detailJump
local detailAbility
local detailActionButton
local detailPriceLabel

-- RemoteFunctions
local PurchaseSkateboardFunc
local EquipSkateboardFunc
local GetSkateboardsFunc

-- プレイヤーデータ
local playerData = {
	owned = {},
	equipped = "BASIC",
	scrap = 0
}

-- デバウンス
local opening = false

-- 関数前方宣言
local updateUI

----------------------------------------------------------------
-- ヘルパー: 状態ラベルの取得
----------------------------------------------------------------
local function getStatusText(boardId, config)
	local owned = table.find(playerData.owned, boardId) ~= nil
	local equipped = (playerData.equipped == boardId) and (playerData.equipped ~= "NONE")
	
	if equipped then
		return "装備済み"
	elseif owned then
		return "装備"
	else
		if config.cost >= 1000000 then
			return string.format("%.1fM", config.cost / 1000000)
		elseif config.cost >= 1000 then
			return string.format("%.1fK", config.cost / 1000)
		else
			return tostring(config.cost)
		end
	end
end

----------------------------------------------------------------
-- UIの初期化
local function setupUI()
	print("[SkateboardShop] Setting up Grid UI...")
	local playerGui = player:WaitForChild("PlayerGui")

	-- ボタン管理用ScreenGui
	local sidebarGui = pgui:FindFirstChild("SidebarGui")
	if not sidebarGui then
		sidebarGui = Instance.new("ScreenGui")
		sidebarGui.Name = "SidebarGui"
		sidebarGui.IgnoreGuiInset = true
		sidebarGui.ResetOnSpawn = false
		sidebarGui.Parent = pgui
	end

	-- ショップボタン（左側に配置）
	shopButton = Instance.new("TextButton")
	shopButton.Name = "SkateboardShopButton"
	shopButton.Size = UDim2.new(0.12, 0, 0.045, 0)
	shopButton.Position = UDim2.new(0.02, 0, 0.32, 0) -- Hammer Shop の下
	shopButton.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
	shopButton.Text = "🛹 SKATE SHOP"
	shopButton.TextColor3 = Color3.new(1, 1, 1)
	shopButton.TextScaled = true
	shopButton.Font = Enum.Font.FredokaOne
	shopButton.Parent = sidebarGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = shopButton
	
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = shopButton

	-- ショップフレーム
	local existingFrame = playerGui:FindFirstChild("SkateboardShop")
	if existingFrame then existingFrame:Destroy() end

	shopFrame = Instance.new("ScreenGui")
	shopFrame.Name = "SkateboardShop"
	shopFrame.ResetOnSpawn = false
	shopFrame.Parent = playerGui

	-- 背景
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(0, 750, 0, 480)
	bg.Position = UDim2.new(0.5, 0, 0.5, 0)
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.BackgroundColor3 = Color3.fromRGB(160, 230, 50) -- 黄緑テーマ
	bg.Parent = shopFrame

	-- 太い黒枠線
	local bgStroke = Instance.new("UIStroke", bg)
	bgStroke.Thickness = 4
	bgStroke.Color = Color3.fromRGB(0, 0, 0)
	bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	
	-- 内側の白い枠線（アクセント）
	local innerStroke = Instance.new("UIStroke", bg)
	innerStroke.Thickness = 1.5
	innerStroke.Color = Color3.fromRGB(255, 255, 255)
	innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = bg

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 750 / 480
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = bg

	local function updateUIScale()
		if not shopFrame then return end
		local screenSize = shopFrame.AbsoluteSize
		local scaleH = math.min(1, screenSize.Y / (480 + 40))
		local scaleW = math.min(1, screenSize.X / (750 + 40))
		uiScale.Scale = math.min(scaleH, scaleW)
	end
	
	shopFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateUIScale)
	updateUIScale()

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 20)
	bgCorner.Parent = bg
	
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Thickness = 4
	bgStroke.Color = Color3.new(1, 1, 1)
	bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bgStroke.Parent = bg

	-- タイトル
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 300, 0, 60)
	title.Position = UDim2.new(0, 30, 0, 5)
	title.BackgroundTransparency = 1
	title.Text = "スケボー"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 36
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = bg
	
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 2
	titleStroke.Parent = title

	-- 閉じるボタン
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 50, 0, 50)
	closeButton.Position = UDim2.new(1, -5, 0, -5)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
	closeButton.Text = "X" -- ✕ -> X
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 30
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = bg

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 12)
	closeCorner.Parent = closeButton
	
	closeButton.Activated:Connect(function()
		shopFrame.Enabled = false
	end)

	-- 左パネル (グリッド)
	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0.6, -40, 1, -80)
	leftPanel.Position = UDim2.new(0, 20, 0, 70)
	leftPanel.BackgroundTransparency = 1
	leftPanel.Parent = bg

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.Parent = leftPanel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 120, 0, 120)
	grid.CellPadding = UDim2.new(0, 10, 0, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scrollFrame

	-- 右パネル (詳細)
	detailPanel = Instance.new("Frame")
	detailPanel.Name = "DetailPanel"
	detailPanel.Size = UDim2.new(0.4, -20, 1, -100)
	detailPanel.Position = UDim2.new(0.6, 0, 0, 80)
	detailPanel.BackgroundColor3 = Color3.new(1, 1, 1)
	detailPanel.Parent = bg

	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, 20)
	detailCorner.Parent = detailPanel
	
	local detailStroke = Instance.new("UIStroke")
	detailStroke.Thickness = 3
	detailStroke.Parent = detailPanel

	detailName = Instance.new("TextLabel")
	detailName.Name = "ItemName"
	detailName.Size = UDim2.new(1, -20, 0, 30)
	detailName.Position = UDim2.new(0, 10, 0, 10)
	detailName.BackgroundTransparency = 1
	detailName.Text = "選択してください"
	detailName.TextColor3 = Color3.new(0, 0, 0)
	detailName.TextSize = 24
	detailName.Font = Enum.Font.GothamBold
	detailName.TextXAlignment = Enum.TextXAlignment.Center
	detailName.Parent = detailPanel

	detailIcon = Instance.new("ImageLabel")
	detailIcon.Name = "BigIcon"
	detailIcon.Size = UDim2.new(0, 150, 0, 150)
	detailIcon.Position = UDim2.new(0.5, 0, 0, 45)
	detailIcon.AnchorPoint = Vector2.new(0.5, 0)
	detailIcon.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
	detailIcon.ScaleType = Enum.ScaleType.Fit
	detailIcon.Parent = detailPanel
	
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 30)
	iconCorner.Parent = detailIcon

	-- ステータス表示
	detailSpeed = Instance.new("TextLabel")
	detailSpeed.Name = "SpeedLabel"
	detailSpeed.Size = UDim2.new(1, -40, 0, 30)
	detailSpeed.Position = UDim2.new(0, 20, 0, 200)
	detailSpeed.BackgroundTransparency = 1
	detailSpeed.Text = "⚡ 速度倍率: x1.0"
	detailSpeed.TextColor3 = Color3.fromRGB(150, 50, 200)
	detailSpeed.TextSize = 24
	detailSpeed.Font = Enum.Font.GothamBold
	detailSpeed.TextXAlignment = Enum.TextXAlignment.Left
	detailSpeed.Parent = detailPanel

	detailJump = Instance.new("TextLabel")
	detailJump.Name = "JumpLabel"
	detailJump.Size = UDim2.new(1, -40, 0, 30)
	detailJump.Position = UDim2.new(0, 20, 0, 235)
	detailJump.BackgroundTransparency = 1
	detailJump.Text = "🚀 ジャンプ力: +0"
	detailJump.TextColor3 = Color3.fromRGB(50, 150, 255)
	detailJump.TextSize = 24
	detailJump.Font = Enum.Font.GothamBold
	detailJump.TextXAlignment = Enum.TextXAlignment.Left
	detailJump.Parent = detailPanel

	detailAbility = Instance.new("TextLabel")
	detailAbility.Name = "AbilityLabel"
	detailAbility.Size = UDim2.new(1, -40, 0, 40)
	detailAbility.Position = UDim2.new(0, 20, 0, 275)
	detailAbility.BackgroundTransparency = 1
	detailAbility.Text = "🕒 特殊能力: --"
	detailAbility.TextColor3 = Color3.fromRGB(50, 150, 50)
	detailAbility.TextSize = 18
	detailAbility.TextWrapped = true
	detailAbility.Font = Enum.Font.GothamBold
	detailAbility.TextXAlignment = Enum.TextXAlignment.Left
	detailAbility.TextYAlignment = Enum.TextYAlignment.Top
	detailAbility.Parent = detailPanel

	detailPriceLabel = Instance.new("TextLabel")
	detailPriceLabel.Name = "PriceLabel"
	detailPriceLabel.Size = UDim2.new(1, -40, 0, 40)
	detailPriceLabel.Position = UDim2.new(0, 20, 0, 320)
	detailPriceLabel.BackgroundTransparency = 1
	detailPriceLabel.Text = "💰 100K"
	detailPriceLabel.TextColor3 = Color3.fromRGB(20, 150, 20)
	detailPriceLabel.TextSize = 30
	detailPriceLabel.Font = Enum.Font.GothamBold
	detailPriceLabel.TextXAlignment = Enum.TextXAlignment.Center
	detailPriceLabel.Parent = detailPanel

	detailActionButton = Instance.new("TextButton")
	detailActionButton.Name = "ActionButton"
	detailActionButton.Size = UDim2.new(0.9, 0, 0, 50)
	detailActionButton.Position = UDim2.new(0.5, 0, 1, -8)
	detailActionButton.AnchorPoint = Vector2.new(0.5, 1)
	detailActionButton.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
	detailActionButton.Text = "購入"
	detailActionButton.TextColor3 = Color3.new(1, 1, 1)
	detailActionButton.TextSize = 28
	detailActionButton.Font = Enum.Font.GothamBold
	detailActionButton.Parent = detailPanel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 15)
	btnCorner.Parent = detailActionButton

	-- グリッドアイテム生成
	for i, boardId in ipairs(SkateboardShopConfig.Order) do
		local config = SkateboardShopConfig.Skateboards[boardId]

		local card = Instance.new("TextButton")
		card.Name = boardId
		card.Size = UDim2.new(0, 120, 0, 120)
		card.BackgroundColor3 = Color3.fromRGB(150, 230, 255)
		card.Text = ""
		card.LayoutOrder = i
		card.Parent = scrollFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 15)
		cardCorner.Parent = card
		
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Thickness = 2
		cardStroke.Parent = card

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(0.8, 0, 0.8, 0)
		icon.Position = UDim2.new(0.5, 0, 0.4, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = config.imageAssetId or ""
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Active = false
		icon.Parent = card

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Status"
		statusLabel.Size = UDim2.new(1, 0, 0, 30)
		statusLabel.Position = UDim2.new(0, 0, 1, -5)
		statusLabel.AnchorPoint = Vector2.new(0, 1)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = getStatusText(boardId, config)
		statusLabel.TextColor3 = Color3.new(0, 0, 0)
		statusLabel.TextSize = 18
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.Parent = card

		boardCards[boardId] = {
			card = card,
			status = statusLabel,
			config = config
		}
		
		card.Activated:Connect(function()
			selectedBoardId = boardId
			updateUI()
		end)
	end

	shopFrame.Enabled = false
	selectedBoardId = "BASIC"
end

----------------------------------------------------------------
-- UIの内容を更新
----------------------------------------------------------------
updateUI = function()
	if not shopFrame then return end

	-- グリッドアイテムの状態を更新
	for boardId, cardData in pairs(boardCards) do
		local card = cardData.card
		local status = cardData.status
		local config = cardData.config
		
		status.Text = getStatusText(boardId, config)
		
		if selectedBoardId == boardId then
			card.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
			card:FindFirstChildWhichIsA("UIStroke").Color = Color3.fromRGB(255, 100, 0)
			card:FindFirstChildWhichIsA("UIStroke").Thickness = 4
		else
			card.BackgroundColor3 = Color3.fromRGB(150, 230, 255)
			card:FindFirstChildWhichIsA("UIStroke").Color = Color3.new(0, 0, 0)
			card:FindFirstChildWhichIsA("UIStroke").Thickness = 2
		end
	end
	
	-- 詳細パネルの更新
	if selectedBoardId then
		local config = SkateboardShopConfig.Skateboards[selectedBoardId]
		if not config then return end

		detailIcon.Image = config.imageAssetId or ""
		detailName.Text = config.displayName or selectedBoardId
		detailSpeed.Text = string.format("⚡ 速度倍率: x%.1f", config.speedMultiplier or 1.0)
		detailJump.Text = string.format("🚀 ジャンプ力: +%d", config.jumpPowerBonus or 0)
		detailAbility.Text = "🕒 特殊能力: " .. (config.description or "なし")
		
		local owned = table.find(playerData.owned, selectedBoardId) ~= nil
		local equipped = (playerData.equipped == selectedBoardId)
		
		if equipped then
			detailActionButton.Text = "装備済み"
			detailActionButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
			detailPriceLabel.Visible = false
		elseif owned then
			detailActionButton.Text = "装備する"
			detailActionButton.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
			detailPriceLabel.Visible = false
		else
			detailPriceLabel.Visible = true
			local costText = tostring(config.cost)
			if config.cost >= 1000000 then
				costText = string.format("%.1fM", config.cost / 1000000)
			elseif config.cost >= 1000 then
				costText = string.format("%.1fk", config.cost / 1000)
			end
			detailPriceLabel.Text = string.format("💰 %s", costText)
			
			if playerData.scrap >= config.cost then
				detailActionButton.Text = "購入"
				detailActionButton.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
			else
				detailActionButton.Text = "不足"
				detailActionButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
			end
		end
	end
end

----------------------------------------------------------------
-- ショップを開く
----------------------------------------------------------------
local function openShop()
	if opening then return end
	opening = true

	local ok, data = pcall(function()
		return GetSkateboardsFunc:InvokeServer()
	end)

	if ok and data then
		playerData.owned = (type(data.owned) == "table") and data.owned or {}
		playerData.equipped = data.equipped or "BASIC"
		playerData.scrap = tonumber(data.scrap) or 0
		selectedBoardId = playerData.equipped
		updateUI()
	end

	if shopFrame then
		shopFrame.Enabled = true
	end

	task.delay(0.25, function()
		opening = false
	end)
end

----------------------------------------------------------------
-- ボタンのイベント設定
----------------------------------------------------------------
local function setupButtons()
	detailActionButton.Activated:Connect(function()
		if not selectedBoardId then return end
		
		local owned = table.find(playerData.owned, selectedBoardId) ~= nil
		local equipped = playerData.equipped == selectedBoardId

		if equipped then
			return
		elseif owned then
			local result = EquipSkateboardFunc:InvokeServer(selectedBoardId)
			if result and result.success then
				playerData.equipped = selectedBoardId
				updateUI()
			end
		else
			local result = PurchaseSkateboardFunc:InvokeServer(selectedBoardId)
			if result and result.success then
				local data = GetSkateboardsFunc:InvokeServer()
				if data then
					playerData.owned = (type(data.owned) == "table") and data.owned or {}
					playerData.equipped = data.equipped or "BASIC"
					playerData.scrap = tonumber(data.scrap) or 0
				end
				updateUI()
			end
		end
	end)

	shopButton.Activated:Connect(openShop)
end

----------------------------------------------------------------
-- ワールドのトリガー
----------------------------------------------------------------
local function bindWorldTrigger()
	task.wait(2)
	local ok, worldShop = pcall(function() return workspace:WaitForChild("shop", 30) end)
	if not ok or not worldShop then return end

	local skateshop = worldShop:FindFirstChild("skateshop")
	if not skateshop then return end

	local trigger = skateshop:FindFirstChild("Trigger", true)
	if trigger then
		local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(p)
				if p == player then openShop() end
			end)
		end
	end
end

----------------------------------------------------------------
-- 初期化
----------------------------------------------------------------
function SkateboardShopController.Init()
	PurchaseSkateboardFunc = Net.F("PurchaseSkateboard")
	EquipSkateboardFunc = Net.F("EquipSkateboard")
	GetSkateboardsFunc = Net.F("GetPlayerSkateboards")

	setupUI()
	setupButtons()
	bindWorldTrigger()
end

return SkateboardShopController
