-- StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua
-- 統合インベントリUI（ハンマー・スケボーの装備切り替え）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local HammerShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HammerShopConfig"))
local SkateboardShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SkateboardShopConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local InventoryController = {}

-- UI参照
local inventoryFrame
local inventoryButton
local itemCards = {}
local selectedItemId = nil
local currentTab = "HAMMERS" -- "HAMMERS" or "SKATEBOARDS"

-- 詳細パネルのパーツ参照
local detailPanel
local detailIcon
local detailName
local detailSpec1
local detailSpec2
local detailAbility
local detailActionButton

-- RemoteFunctions
local GetHammersFunc
local GetSkateboardsFunc
local EquipHammerFunc
local EquipSkateboardFunc

-- プレイヤーデータ
local playerData = {
	hammers = { owned = {}, equipped = "BASIC" },
	skateboards = { owned = {}, equipped = "BASIC" }
}

-- デバウンス
local opening = false

-- 関数前方宣言
local updateUI
local refreshData

----------------------------------------------------------------
-- UIの初期化
----------------------------------------------------------------
local function setupUI()
	print("[Inventory] Setting up Unified UI...")
	local playerGui = player:WaitForChild("PlayerGui")
	local mainHud = playerGui:WaitForChild("MainHud")

	-- インベントリボタンを作成（ペットボタンとは別）
	inventoryButton = mainHud:FindFirstChild("InventoryButton")
	if not inventoryButton then
		inventoryButton = Instance.new("TextButton")
		inventoryButton.Name = "InventoryButton"
		inventoryButton.Parent = mainHud
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 15)
		corner.Parent = inventoryButton
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 2
		stroke.Parent = inventoryButton
	end

	-- デザインの更新（既存のボタンにも適用）
	inventoryButton.Size = UDim2.new(0, 45, 0, 45)
	inventoryButton.Position = UDim2.new(0.5, 0, 1, -20)
	inventoryButton.AnchorPoint = Vector2.new(0.5, 1)
	inventoryButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
	inventoryButton.BackgroundTransparency = 0.5 -- 透過設定
	inventoryButton.RichText = true
	inventoryButton.Text = "<font size=\"20\">🔨🛹</font>\n<font size=\"8\">inventory</font>"
	inventoryButton.Font = Enum.Font.FredokaOne

	-- 古いインベントリフレームがあれば削除
	local oldFrame = playerGui:FindFirstChild("InventoryFrame") or playerGui:FindFirstChild("Inventory")
	if oldFrame then oldFrame:Destroy() end

	inventoryFrame = Instance.new("ScreenGui")
	inventoryFrame.Name = "Inventory"
	inventoryFrame.ResetOnSpawn = false
	inventoryFrame.Parent = playerGui

	-- 背景
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(0, 750, 0, 480)
	bg.Position = UDim2.new(0.5, 0, 0.5, 0)
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.BackgroundColor3 = Color3.fromRGB(160, 230, 50) -- 黄緑テーマ
	bg.Parent = inventoryFrame

	-- 太い黒枠線
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Thickness = 4
	bgStroke.Color = Color3.fromRGB(0, 0, 0)
	bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bgStroke.Parent = bg
	
	-- 内側の白い枠線（アクセント）
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Thickness = 1.5
	innerStroke.Color = Color3.fromRGB(255, 255, 255)
	innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerStroke.Parent = bg

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = bg

	-- モバイルスケーリングロジック
	local function updateUIScale()
		if not inventoryFrame then return end
		local screenSize = inventoryFrame.AbsoluteSize
		local scaleH = math.min(1, screenSize.Y / (480 + 40))
		local scaleW = math.min(1, screenSize.X / (750 + 40))
		uiScale.Scale = math.min(scaleH, scaleW)
	end
	inventoryFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateUIScale)
	updateUIScale()

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 20)
	bgCorner.Parent = bg

	-- タブボタン
	local hammerTab = Instance.new("TextButton")
	hammerTab.Name = "HammerTab"
	hammerTab.Size = UDim2.new(0, 150, 0, 50)
	hammerTab.Position = UDim2.new(0, 20, 0, 15)
	hammerTab.BackgroundColor3 = Color3.fromRGB(210, 210, 220)
	hammerTab.Text = "🔨 ハンマー"
	hammerTab.TextColor3 = Color3.new(0, 0, 0)
	hammerTab.Font = Enum.Font.GothamBold
	hammerTab.TextSize = 18
	hammerTab.Parent = bg
	
	Instance.new("UICorner", hammerTab).CornerRadius = UDim.new(0, 12) -- タブ角丸
	local hStroke = Instance.new("UIStroke", hammerTab)
	hStroke.Thickness = 2
	hStroke.Color = Color3.fromRGB(0, 0, 0)

	local skateboardTab = Instance.new("TextButton")
	skateboardTab.Name = "SkateboardTab"
	skateboardTab.Size = UDim2.new(0, 150, 0, 50)
	skateboardTab.Position = UDim2.new(0, 180, 0, 15)
	skateboardTab.BackgroundColor3 = Color3.fromRGB(210, 210, 220)
	skateboardTab.Text = "🛹 スケボー"
	skateboardTab.TextColor3 = Color3.new(0, 0, 0)
	skateboardTab.Font = Enum.Font.GothamBold
	skateboardTab.TextSize = 18
	skateboardTab.Parent = bg
	
	Instance.new("UICorner", skateboardTab).CornerRadius = UDim.new(0, 12) -- タブ角丸
	local sStroke = Instance.new("UIStroke", skateboardTab)
	sStroke.Thickness = 2
	sStroke.Color = Color3.fromRGB(0, 0, 0)

	-- 閉じるボタン
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 50, 0, 50)
	closeButton.Position = UDim2.new(1, -5, 0, -5)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 30
	closeButton.Parent = bg

	closeButton.Activated:Connect(function()
		inventoryFrame.Enabled = false
	end)

	-- 左パネル (アイテムグリッド)
	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0.6, -40, 1, -100)
	leftPanel.Position = UDim2.new(0, 20, 0, 80)
	leftPanel.BackgroundTransparency = 1
	leftPanel.Parent = bg

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.Parent = leftPanel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 130, 0, 130)
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

	detailName = Instance.new("TextLabel")
	detailName.Size = UDim2.new(1, -20, 0, 30)
	detailName.Position = UDim2.new(0, 10, 0, 10)
	detailName.BackgroundTransparency = 1
	detailName.Text = "アイテムを選択"
	detailName.TextColor3 = Color3.new(0, 0, 0)
	detailName.Font = Enum.Font.GothamBold
	detailName.TextSize = 22
	detailName.Parent = detailPanel

	detailIcon = Instance.new("ImageLabel")
	detailIcon.Size = UDim2.new(0, 150, 0, 150)
	detailIcon.Position = UDim2.new(0.5, 0, 0, 45)
	detailIcon.AnchorPoint = Vector2.new(0.5, 0)
	detailIcon.BackgroundTransparency = 1
	detailIcon.ScaleType = Enum.ScaleType.Fit
	detailIcon.Parent = detailPanel

	detailSpec1 = Instance.new("TextLabel")
	detailSpec1.Size = UDim2.new(1, -40, 0, 30)
	detailSpec1.Position = UDim2.new(0, 20, 0, 205)
	detailSpec1.BackgroundTransparency = 1
	detailSpec1.Text = "--"
	detailSpec1.TextColor3 = Color3.fromRGB(150, 50, 200)
	detailSpec1.Font = Enum.Font.GothamBold
	detailSpec1.TextSize = 20
	detailSpec1.TextXAlignment = Enum.TextXAlignment.Left
	detailSpec1.Parent = detailPanel

	detailSpec2 = Instance.new("TextLabel")
	detailSpec2.Size = UDim2.new(1, -40, 0, 30)
	detailSpec2.Position = UDim2.new(0, 20, 0, 235)
	detailSpec2.BackgroundTransparency = 1
	detailSpec2.Text = "--"
	detailSpec2.TextColor3 = Color3.fromRGB(50, 150, 255)
	detailSpec2.Font = Enum.Font.GothamBold
	detailSpec2.TextSize = 20
	detailSpec2.TextXAlignment = Enum.TextXAlignment.Left
	detailSpec2.Parent = detailPanel

	detailAbility = Instance.new("TextLabel")
	detailAbility.Size = UDim2.new(1, -40, 0, 50)
	detailAbility.Position = UDim2.new(0, 20, 0, 265)
	detailAbility.BackgroundTransparency = 1
	detailAbility.Text = "--"
	detailAbility.TextColor3 = Color3.fromRGB(50, 120, 50)
	detailAbility.Font = Enum.Font.GothamBold
	detailAbility.TextSize = 16
	detailAbility.TextWrapped = true
	detailAbility.TextXAlignment = Enum.TextXAlignment.Left
	detailAbility.TextYAlignment = Enum.TextYAlignment.Top
	detailAbility.Parent = detailPanel

	detailActionButton = Instance.new("TextButton")
	detailActionButton.Size = UDim2.new(0.9, 0, 0, 50)
	detailActionButton.Position = UDim2.new(0.5, 0, 1, -10)
	detailActionButton.AnchorPoint = Vector2.new(0.5, 1)
	detailActionButton.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
	detailActionButton.Text = "装備"
	detailActionButton.TextColor3 = Color3.new(1, 1, 1)
	detailActionButton.Font = Enum.Font.GothamBold
	detailActionButton.TextSize = 24
	detailActionButton.Parent = detailPanel
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 15)
	btnCorner.Parent = detailActionButton

	-- タブクリックイベント
	hammerTab.Activated:Connect(function()
		currentTab = "HAMMERS"
		selectedItemId = nil
		updateUI()
	end)
	skateboardTab.Activated:Connect(function()
		currentTab = "SKATEBOARDS"
		selectedItemId = nil
		updateUI()
	end)

	-- 初期状態
	inventoryFrame.Enabled = false
end

----------------------------------------------------------------
-- データをリフレッシュ
----------------------------------------------------------------
refreshData = function()
	local okH, hData = pcall(function() return GetHammersFunc:InvokeServer() end)
	if okH and hData then
		playerData.hammers.owned = hData.owned or {}
		playerData.hammers.equipped = hData.equipped or "BASIC"
	end

	local okS, sData = pcall(function() return GetSkateboardsFunc:InvokeServer() end)
	if okS and sData then
		playerData.skateboards.owned = sData.owned or {}
		playerData.skateboards.equipped = sData.equipped or "BASIC"
	end
end

----------------------------------------------------------------
-- UIを更新
----------------------------------------------------------------
updateUI = function()
	if not inventoryFrame then return end
	local scrollFrame = inventoryFrame.Background.LeftPanel.ScrollFrame
	
	-- タブのハイライト
	local bg = inventoryFrame.Background
	bg.HammerTab.BackgroundColor3 = (currentTab == "HAMMERS") and Color3.fromRGB(0, 190, 245) or Color3.fromRGB(210, 210, 220)
	bg.SkateboardTab.BackgroundColor3 = (currentTab == "SKATEBOARDS") and Color3.fromRGB(0, 190, 245) or Color3.fromRGB(210, 210, 220)

	-- グリッドのクリア
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	itemCards = {}

	-- アイテムリストの作成
	local currentCategory = (currentTab == "HAMMERS") and playerData.hammers or playerData.skateboards
	local configTable = (currentTab == "HAMMERS") and HammerShopConfig.Hammers or SkateboardShopConfig.Skateboards
	local order = (currentTab == "HAMMERS") and HammerShopConfig.Order or SkateboardShopConfig.Order

	-- ショップと同じ順序で、所有しているアイテムのみ表示
	for i, itemId in ipairs(order) do
		if table.find(currentCategory.owned, itemId) then
			local config = configTable[itemId]
			local card = Instance.new("TextButton")
			card.Name = itemId
			card.Size = UDim2.new(0, 130, 0, 130)
			card.BackgroundColor3 = Color3.fromRGB(150, 230, 255)
			card.Text = ""
			card.LayoutOrder = i -- ショップと同じ順序を維持
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

			-- 装備中マークをステータスラベルとして表示
			local statusLabel = Instance.new("TextLabel")
			statusLabel.Name = "Status"
			statusLabel.Size = UDim2.new(1, 0, 0, 30)
			statusLabel.Position = UDim2.new(0, 0, 1, -5)
			statusLabel.AnchorPoint = Vector2.new(0, 1)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Text = (currentCategory.equipped == itemId) and "✓ 装備中" or ""
			statusLabel.TextColor3 = Color3.new(0, 0, 0)
			statusLabel.TextSize = 18
			statusLabel.Font = Enum.Font.GothamBold
			statusLabel.Parent = card
			
			local statusStroke = Instance.new("UIStroke")
			statusStroke.Thickness = 1.5
			statusStroke.Color = Color3.new(1, 1, 1)
			statusStroke.Parent = statusLabel

			-- ハイライト（選択中）
			if selectedItemId == itemId then
				card.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
				cardStroke.Color = Color3.fromRGB(255, 100, 0)
				cardStroke.Thickness = 4
			end

			card.Activated:Connect(function()
				selectedItemId = itemId
				updateUI()
			end)
			
			itemCards[itemId] = card
		end
	end

	-- 詳細パネルの更新
	if selectedItemId then
		local config = configTable[selectedItemId]
		if not config then
			-- configが存在しない場合はリセット
			selectedItemId = nil
			detailName.Text = "アイテムを選択"
			detailIcon.Image = ""
			detailSpec1.Text = "--"
			detailSpec2.Text = "--"
			detailAbility.Text = "--"
			detailActionButton.Text = "装備"
			detailActionButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
			return
		end
		
		detailName.Text = config.displayName or selectedItemId
		detailIcon.Image = config.imageAssetId or ""
		
		if currentTab == "HAMMERS" then
			detailSpec1.Text = string.format("⚡ ダメージ: x%.1f", config.damageMultiplier or 1.0)
			local limit = GameConfig.HammerCanLimit[selectedItemId] or 1
			
			-- 潰せる缶の色リストを作成
			local canColors = {}
			if limit >= 1 then table.insert(canColors, "赤") end
			if limit >= 2 then table.insert(canColors, "青") end
			if limit >= 3 then table.insert(canColors, "緑") end
			if limit >= 4 then table.insert(canColors, "紫") end
			if limit >= 5 then table.insert(canColors, "黄") end
			
			local colorList = table.concat(canColors, ", ")
			detailSpec2.Text = "🎯 潰せる缶: " .. colorList
			detailAbility.Text = "🕒 能力: " .. (config.description or "なし")
		else
			detailSpec1.Text = string.format("⚡ 速度: x%.1f", config.speedMultiplier or 1.0)
			detailSpec2.Text = string.format("🚀 ジャンプ: +%d", config.jumpPowerBonus or 0)
			detailAbility.Text = "🕒 能力: " .. (config.description or "なし")
		end

		local isEquipped = (currentCategory.equipped == selectedItemId)
		if isEquipped then
			detailActionButton.Text = "装備中"
			detailActionButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		else
			detailActionButton.Text = "装備"
			detailActionButton.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
		end
	else
		detailName.Text = "アイテムを選択"
		detailIcon.Image = ""
		detailSpec1.Text = "--"
		detailSpec2.Text = "--"
		detailAbility.Text = "--"
		detailActionButton.Text = "装備"
		detailActionButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	end
end

----------------------------------------------------------------
-- 装備処理
----------------------------------------------------------------
local function handleEquip()
	if not selectedItemId then return end
	
	if currentTab == "HAMMERS" then
		if playerData.hammers.equipped == selectedItemId then return end
		local result = EquipHammerFunc:InvokeServer(selectedItemId)
		if result and result.success then
			playerData.hammers.equipped = selectedItemId
			updateUI()
		end
	else
		if playerData.skateboards.equipped == selectedItemId then return end
		local result = EquipSkateboardFunc:InvokeServer(selectedItemId)
		if result and result.success then
			playerData.skateboards.equipped = selectedItemId
			updateUI()
		end
	end
end

----------------------------------------------------------------
-- 初期化
----------------------------------------------------------------
function InventoryController.Init()
	print("[InventoryController] Init")

	GetHammersFunc = Net.F(Constants.Functions.GetPlayerHammers)
	GetSkateboardsFunc = Net.F(Constants.Functions.GetPlayerSkateboards)
	EquipHammerFunc = Net.F(Constants.Functions.EquipHammer)
	EquipSkateboardFunc = Net.F(Constants.Functions.EquipSkateboard)

	setupUI()
	
	detailActionButton.Activated:Connect(handleEquip)
	
	inventoryButton.Activated:Connect(function()
		if opening then return end
		opening = true
		
		if not inventoryFrame.Enabled then
			refreshData()
			selectedItemId = (currentTab == "HAMMERS") and playerData.hammers.equipped or playerData.skateboards.equipped
			updateUI()
		end
		
		inventoryFrame.Enabled = not inventoryFrame.Enabled
		
		task.delay(0.3, function() opening = false end)
	end)

	-- 外部からのデータ更新検知
	player:GetAttributeChangedSignal("EquippedHammer"):Connect(function()
		playerData.hammers.equipped = player:GetAttribute("EquippedHammer") or "BASIC"
		if inventoryFrame.Enabled then updateUI() end
	end)
end

return InventoryController
