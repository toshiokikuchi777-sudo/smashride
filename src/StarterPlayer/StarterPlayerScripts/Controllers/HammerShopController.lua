-- StarterPlayer/StarterPlayerScripts/Controllers/HammerShopController.lua
-- ハンマーショップのクライアント側処理

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local HammerShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HammerShopConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local HammerShopController = {}

-- UI参照
local shopFrame
local shopButton
local hammerCards = {}
local selectedHammerId = nil -- 現在選択中のハンマーID

-- 詳細パネルのパーツ参照
local detailPanel
local detailIcon
local detailName
local detailDamage
local detailAbility
local detailLimit
local detailActionButton
local detailPriceIcon
local detailPriceLabel

-- RemoteFunctions
local PurchaseHammerFunc
local EquipHammerFunc
local GetHammersFunc

-- プレイヤーデータ
local playerData = {
	owned = {},
	equipped = "BASIC",
	scrap = 0
}

-- デバウンス（連打/連続発火防止）
local opening = false

-- 関数前方宣言
local updateUI

----------------------------------------------------------------
-- ヘルパー: 状態ラベルの取得
----------------------------------------------------------------
local function getStatusText(hammerId, config)
	local owned = table.find(playerData.owned, hammerId) ~= nil
	local equipped = (playerData.equipped == hammerId) and (playerData.equipped ~= "NONE")
	
	if equipped then
		return "装備済み"
	elseif owned then
		return "装備"
	else
		-- 特殊ハンマー（コミュニティ報酬など）かつ未所有の場合
		if config.isSpecial then
			return "LOCKED"
		end

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
	print("[HammerShop] Setting up Grid UI...")
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
	shopButton.Name = "HammerShopButton"
	shopButton.Size = UDim2.new(0.12, 0, 0.045, 0)
	shopButton.Position = UDim2.new(0.02, 0, 0.26, 0)
	shopButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	shopButton.Text = "🔨 HAMMER SHOP"
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
	local existingFrame = playerGui:FindFirstChild("HammerShop")
	if existingFrame then existingFrame:Destroy() end

	shopFrame = Instance.new("ScreenGui")
	shopFrame.Name = "HammerShop"
	shopFrame.ResetOnSpawn = false
	shopFrame.Parent = playerGui

	-- 背景 (メイン)
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(0, 750, 0, 480) -- 550 -> 480
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
	aspect.AspectRatio = 750 / 480 -- 指定した背景サイズに基づく
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = bg

	-- モバイル対応：画面高さに合わせて自動スケーリング
	local function updateUIScale()
		if not shopFrame then return end
		local screenSize = shopFrame.AbsoluteSize
		local targetHeight = 480 -- 設計上の高さ
		local targetWidth = 750  -- 設計上の幅

		-- 画面高さが足りない場合に縮小する
		local scaleH = math.min(1, screenSize.Y / (targetHeight + 40)) -- 余白分を考慮
		local scaleW = math.min(1, screenSize.X / (targetWidth + 40))
		uiScale.Scale = math.min(scaleH, scaleW)
	end
	
	shopFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateUIScale)
	updateUIScale()

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 20)
	bgCorner.Parent = bg
	
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Thickness = 4
	bgStroke.Color = Color3.fromRGB(255, 255, 255)
	bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bgStroke.Parent = bg

	-- タイトル
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 300, 0, 60)
	title.Position = UDim2.new(0, 30, 0, 5)
	title.BackgroundTransparency = 1
	title.Text = "ハンマー"
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
	closeButton.Text = "X" -- ✕ -> X (文字化け対策)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 30
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = bg

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 12)
	closeCorner.Parent = closeButton
	
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Thickness = 3
	closeStroke.Color = Color3.new(0, 0, 0)
	closeStroke.Parent = closeButton

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

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 15)
	listLayout.Parent = scrollFrame

	-- 自動スクロールサイズ調整
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
	end)

	-- カテゴリコンテナ作成ヘルパー
	local function createSection(name, order)
		local sectionFrame = Instance.new("Frame")
		sectionFrame.Name = name .. "Section"
		sectionFrame.Size = UDim2.new(1, 0, 0, 0)
		sectionFrame.BackgroundTransparency = 1
		sectionFrame.LayoutOrder = order
		sectionFrame.Parent = scrollFrame

		local header = Instance.new("TextLabel")
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, 30)
		header.BackgroundTransparency = 1
		header.Text = name
		header.TextColor3 = Color3.new(1, 1, 1)
		header.TextSize = 20
		header.Font = Enum.Font.GothamBold
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = sectionFrame
		
		local hStroke = Instance.new("UIStroke")
		hStroke.Thickness = 1.5
		hStroke.Parent = header

		local grid = Instance.new("UIGridLayout")
		grid.Name = "Grid"
		grid.CellSize = UDim2.new(0, 120, 0, 120)
		grid.CellPadding = UDim2.new(0, 10, 0, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = sectionFrame

		-- コンテナの高さをグリッドに合わせる
		grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			sectionFrame.Size = UDim2.new(1, 0, 0, grid.AbsoluteContentSize.Y + 40)
		end)

		return sectionFrame
	end

	local standardSection = createSection("STANDARD ITEMS", 1)
	local specialSection = createSection("SPECIAL ITEMS", 2)

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
	detailName.TextColor3 = Color3.new(0, 0, 0) -- 黒
	detailName.TextSize = 24
	detailName.Font = Enum.Font.GothamBold
	detailName.TextXAlignment = Enum.TextXAlignment.Center
	detailName.Parent = detailPanel
	
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 1.5
	nameStroke.Color = Color3.new(1, 1, 1)
	nameStroke.Parent = detailName

	detailIcon = Instance.new("ImageLabel")
	detailIcon.Name = "BigIcon"
	detailIcon.Size = UDim2.new(0, 150, 0, 150) -- 180 -> 150
	detailIcon.Position = UDim2.new(0.5, 0, 0, 45)
	detailIcon.AnchorPoint = Vector2.new(0.5, 0)
	detailIcon.BackgroundColor3 = Color3.fromRGB(255, 200, 0) -- オレンジっぽく
	detailIcon.ScaleType = Enum.ScaleType.Fit
	detailIcon.Parent = detailPanel
	
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 30)
	iconCorner.Parent = detailIcon
	
	local iconStroke = Instance.new("UIStroke")
	iconStroke.Thickness = 3
	iconStroke.Parent = detailIcon

	-- ステータス表示
	detailDamage = Instance.new("TextLabel")
	detailDamage.Name = "DamageLabel"
	detailDamage.Size = UDim2.new(1, -40, 0, 30) -- 40 -> 30
	detailDamage.Position = UDim2.new(0, 20, 0, 200) -- 240 -> 200
	detailDamage.BackgroundTransparency = 1
	detailDamage.Text = "⚡ ダメージ: x1.0"
	detailDamage.TextColor3 = Color3.fromRGB(150, 50, 200)
	detailDamage.TextSize = 24 -- 32 -> 24
	detailDamage.Font = Enum.Font.GothamBold
	detailDamage.TextXAlignment = Enum.TextXAlignment.Left
	detailDamage.Parent = detailPanel

	detailAbility = Instance.new("TextLabel")
	detailAbility.Name = "AbilityLabel"
	detailAbility.Size = UDim2.new(1, -40, 0, 40)
	detailAbility.Position = UDim2.new(0, 20, 0, 235) -- 285 -> 235
	detailAbility.BackgroundTransparency = 1
	detailAbility.Text = "🕒 特殊能力 (アビリティ): --"
	detailAbility.TextColor3 = Color3.fromRGB(50, 150, 255)
	detailAbility.TextSize = 18 -- 20 -> 18
	detailAbility.TextWrapped = true
	detailAbility.Font = Enum.Font.GothamBold
	detailAbility.TextXAlignment = Enum.TextXAlignment.Left
	detailAbility.TextYAlignment = Enum.TextYAlignment.Top
	detailAbility.Parent = detailPanel

	detailLimit = Instance.new("TextLabel")
	detailLimit.Name = "LimitLabel"
	detailLimit.Size = UDim2.new(1, -40, 0, 30) -- 40 -> 30
	detailLimit.Position = UDim2.new(0, 20, 0, 280) -- 330 -> 280
	detailLimit.BackgroundTransparency = 1
	detailLimit.Text = "🎯 潰せる缶: 赤"
	detailLimit.TextColor3 = Color3.fromRGB(200, 50, 50)
	detailLimit.TextSize = 22 -- 32 -> 22
	detailLimit.TextWrapped = true
	detailLimit.Font = Enum.Font.GothamBold
	detailLimit.TextXAlignment = Enum.TextXAlignment.Left
	detailLimit.TextYAlignment = Enum.TextYAlignment.Top
	detailLimit.Parent = detailPanel

	-- 価格ラベル
	detailPriceLabel = Instance.new("TextLabel")
	detailPriceLabel.Name = "PriceLabel"
	detailPriceLabel.Size = UDim2.new(1, -40, 0, 40)
	detailPriceLabel.Position = UDim2.new(0, 20, 0, 320)
	detailPriceLabel.BackgroundTransparency = 1
	detailPriceLabel.Text = " 150K"
	detailPriceLabel.TextColor3 = Color3.fromRGB(20, 150, 20)
	detailPriceLabel.TextSize = 30
	detailPriceLabel.Font = Enum.Font.GothamBold
	detailPriceLabel.TextXAlignment = Enum.TextXAlignment.Center
	detailPriceLabel.Parent = detailPanel

	-- 購入・装備ボタン
	detailActionButton = Instance.new("TextButton")
	detailActionButton.Name = "ActionButton"
	detailActionButton.Size = UDim2.new(0.9, 0, 0, 50) -- 70 -> 50
	detailActionButton.Position = UDim2.new(0.5, 0, 1, -8)
	detailActionButton.AnchorPoint = Vector2.new(0.5, 1)
	detailActionButton.BackgroundColor3 = Color3.fromRGB(0, 200, 50) -- 鮮やかな緑
	detailActionButton.Text = "購入"
	detailActionButton.TextColor3 = Color3.new(1, 1, 1)
	detailActionButton.TextSize = 28 -- 36 -> 28
	detailActionButton.Font = Enum.Font.GothamBold
	detailActionButton.Parent = detailPanel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 15)
	btnCorner.Parent = detailActionButton
	
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Thickness = 3
	btnStroke.Parent = detailActionButton

	-- グリッドアイテム生成
	for i, hammerId in ipairs(HammerShopConfig.Order) do
		local config = HammerShopConfig.Hammers[hammerId]

		local card = Instance.new("TextButton")
		card.Name = hammerId
		card.Size = UDim2.new(0, 130, 0, 130)
		card.BackgroundColor3 = Color3.fromRGB(150, 230, 255)
		card.Text = ""
		card.LayoutOrder = i
		
		-- 振り分け
		if config.isSpecial then
			card.Parent = specialSection
		else
			card.Parent = standardSection
		end

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
		icon.Active = false -- クリックをブロックしないように
		icon.Parent = card

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Status"
		statusLabel.Size = UDim2.new(1, 0, 0, 30)
		statusLabel.Position = UDim2.new(0, 0, 1, -5)
		statusLabel.AnchorPoint = Vector2.new(0, 1)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = getStatusText(hammerId, config)
		statusLabel.TextColor3 = Color3.new(0, 0, 0)
		statusLabel.TextSize = 18
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.Parent = card
		
		local statusStroke = Instance.new("UIStroke")
		statusStroke.Thickness = 1.5
		statusStroke.Color = Color3.new(1, 1, 1)
		statusStroke.Parent = statusLabel

		hammerCards[hammerId] = {
			card = card,
			status = statusLabel,
			config = config
		}
		
		-- クリックで選択
		card.Activated:Connect(function()
			selectedHammerId = hammerId
			updateUI()
		end)
	end

	shopFrame.Enabled = false
	
	-- 初期選択
	selectedHammerId = "BASIC"
end

----------------------------------------------------------------
-- UIの内容を更新
----------------------------------------------------------------
updateUI = function()
	print("[HammerShop] updateUI called for:", tostring(selectedHammerId))
	if not shopFrame then return end

	local scrapLabel = shopFrame.Background:FindFirstChild("ScrapLabel")
	if scrapLabel then
		scrapLabel.Text = "SCRAP: " .. playerData.scrap
	end

	-- グリッドアイテムの状態を更新
	for hammerId, cardData in pairs(hammerCards) do
		local card = cardData.card
		local status = cardData.status
		local config = cardData.config
		
		status.Text = getStatusText(hammerId, config)
		
		-- 選択中のハイライト
		if selectedHammerId == hammerId then
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
	if selectedHammerId then
		local config = HammerShopConfig.Hammers[selectedHammerId]
		if not config then return end

		-- 画像と名前を更新
		detailIcon.Image = config.imageAssetId or ""
		detailName.Text = config.displayName or selectedHammerId
		
		-- ステータスを更新 (最新スペック)
		detailDamage.Text = string.format("⚡ ダメージ: x%.1f", config.damageMultiplier or 1.0)
		
		-- 能力名 (Configから取得。同期不具合対策としてController側にも定義)
		local desc = config.description
		if not desc or desc == "" or desc == "なし" then
			if selectedHammerId == "SHOCKWAVE" then desc = "周りの缶を破壊"
			elseif selectedHammerId == "MULTI" then desc = "ポイント倍増"
			elseif selectedHammerId == "HYBRID" then desc = "周りの缶を破壊＆ポイント倍増"
			elseif selectedHammerId == "MASTER" then desc = "周りの缶を破壊＆ポイント倍増＆全種破壊"
			else desc = "なし"
			end
		end
		detailAbility.Text = "🕒 特殊能力 (アビリティ): " .. desc

		-- 破壊制限
		local limitLevel = GameConfig.HammerCanLimit[selectedHammerId] or 1
		
		-- 潰せる缶の色リストを作成
		local canColors = {}
		if limitLevel >= 1 then table.insert(canColors, "赤") end
		if limitLevel >= 2 then table.insert(canColors, "青") end
		if limitLevel >= 3 then table.insert(canColors, "緑") end
		if limitLevel >= 4 then table.insert(canColors, "紫") end
		if limitLevel >= 5 then table.insert(canColors, "黄") end
		
		local colorList = table.concat(canColors, ", ")
		detailLimit.Text = "🎯 潰せる缶: " .. colorList
		
		-- ボタンと価格の更新
		local owned = table.find(playerData.owned, selectedHammerId) ~= nil
		local equipped = (playerData.equipped == selectedHammerId)
		
		if equipped then
			detailActionButton.Text = "装備済み"
			detailActionButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
			detailPriceLabel.Visible = false
		elseif owned then
			detailActionButton.Text = "装備する"
			detailActionButton.BackgroundColor3 = Color3.fromRGB(230, 126, 34) -- オレンジ
			detailPriceLabel.Visible = false
		else
			-- 未所有：購入
			detailPriceLabel.Visible = true
			
			if config.isSpecial then
				-- 特殊ハンマーは価格表示ではなくLOCKED案内
				detailPriceLabel.Text = "COMMUNITY限定"
				detailPriceLabel.TextColor3 = Color3.fromRGB(200, 50, 50) -- 赤
				
				detailActionButton.Text = "LOCKED"
				detailActionButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
			else
				-- 通貨単位の調整 (K表示など)
				local costText = tostring(config.cost)
				if config.cost >= 1000 then
					costText = string.format("%.1fK", config.cost / 1000)
				end
				detailPriceLabel.Text = string.format("💰 %s", costText)
				detailPriceLabel.TextColor3 = Color3.fromRGB(20, 150, 20) -- 緑
				
				if playerData.scrap >= config.cost then
					detailActionButton.Text = "購入"
					detailActionButton.BackgroundColor3 = Color3.fromRGB(0, 200, 50) -- 緑
				else
					detailActionButton.Text = "不足"
					detailActionButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
				end
			end
		end
	else
		-- 選択されていない場合
		detailName.Text = "選択してください"
		detailIcon.Image = ""
		detailDamage.Text = "⚡ --"
		detailAbility.Text = "🕒 --"
		detailLimit.Text = "🚫 --"
		detailPriceLabel.Visible = false
		detailActionButton.Text = "--"
	end
end

----------------------------------------------------------------
-- 共通：ショップを開く
----------------------------------------------------------------
local function openShop()
	if opening then return end
	opening = true

	local ok, data = pcall(function()
		return GetHammersFunc:InvokeServer()
	end)

	if ok and data then
		playerData.owned = (type(data.owned) == "table") and data.owned or {}
		playerData.equipped = data.equipped or "BASIC"
		playerData.scrap = tonumber(data.scrap) or 0
		
		-- 現在装備しているハンマーを選択状態にする
		selectedHammerId = playerData.equipped
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
	print("[HammerShop] setupButtons called, detailActionButton:", detailActionButton)
	-- 詳細パネルのアクションボタン
	if detailActionButton then
		print("[HammerShop] Connecting detailActionButton.Activated event")
		detailActionButton.Activated:Connect(function()
			print("[HammerShop] Action button clicked, selectedHammerId:", selectedHammerId)
			if not selectedHammerId then return end
			
			local owned = table.find(playerData.owned, selectedHammerId) ~= nil
			local equipped = playerData.equipped == selectedHammerId
			print("[HammerShop] owned:", owned, "equipped:", equipped)

			if equipped then
				print("[HammerShop] Already equipped, returning")
				return
			elseif owned then
				print("[HammerShop] Equipping hammer:", selectedHammerId)
				local result = EquipHammerFunc:InvokeServer(selectedHammerId)
				print("[HammerShop] Equip result:", result)
				if result and result.success then
					playerData.equipped = selectedHammerId
					updateUI()
				end
			else
				-- 未所有の場合
				local config = HammerShopConfig.Hammers[selectedHammerId]
				if config and config.isSpecial then
					print("[HammerShop] Hammer is locked/special, ignoring purchase click")
					return
				end

				print("[HammerShop] Purchasing hammer:", selectedHammerId)
				local result = PurchaseHammerFunc:InvokeServer(selectedHammerId)
				if result and result.success then
					-- 最新データを取得して更新
					local data = GetHammersFunc:InvokeServer()
					if data then
						playerData.owned = (type(data.owned) == "table") and data.owned or {}
						playerData.equipped = data.equipped or "BASIC"
						playerData.scrap = tonumber(data.scrap) or 0
					end
					updateUI()
				end
			end
		end)
	else
		warn("[HammerShop] detailActionButton is nil in setupButtons!")
	end

	-- ショップボタン → openShopに統一
	if shopButton then
		shopButton.Activated:Connect(openShop)
	end
end

----------------------------------------------------------------
-- ワールドのトリガー（hammershopのTrigger.ProximityPrompt）
----------------------------------------------------------------
local function bindWorldTrigger()
	-- ワールドの読み込みを待つ（ゲームクライアントでは時間がかかる場合がある）
	task.wait(2)
	
	local ok, worldShop = pcall(function()
		return workspace:WaitForChild("shop", 30)  -- 30秒待機
	end)
	if not ok or not worldShop then
		warn("[HammerShop] workspace.shop not found after 30 seconds")
		return
	end

	local hammershop = worldShop:FindFirstChild("hammershop")
	if not hammershop then
		warn("[HammerShop] workspace.shop.hammershop not found")
		return
	end

	local trigger = hammershop:FindFirstChild("Trigger", true)
	if not trigger then
		warn("[HammerShop] Trigger part not found under hammershop (create Part named Trigger)")
		return
	end

	local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn("[HammerShop] ProximityPrompt not found in Trigger")
		return
	end

	prompt.Triggered:Connect(function(p)
		if p ~= player then return end
		print("[HammerShop] Trigger activated by", player.Name)
		
		-- UIが準備できているか確認
		if not shopFrame then
			warn("[HammerShop] ShopFrame not ready yet")
			return
		end
		
		openShop()
	end)

	print("[HammerShop] World trigger bound")
end

----------------------------------------------------------------
-- 初期化
----------------------------------------------------------------
function HammerShopController.Init()
	print("[HammerShopController] Init")

	local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))

	-- RemoteFunctions を取得
	PurchaseHammerFunc = Net.F(Constants.Functions.PurchaseHammer)
	EquipHammerFunc = Net.F(Constants.Functions.EquipHammer)
	GetHammersFunc = Net.F(Constants.Functions.GetPlayerHammers)

	-- UI セットアップ
	setupUI()
	setupButtons()

	-- ワールドトリガー紐付け
	bindWorldTrigger()

	print("[HammerShopController] Ready")
end

return HammerShopController
