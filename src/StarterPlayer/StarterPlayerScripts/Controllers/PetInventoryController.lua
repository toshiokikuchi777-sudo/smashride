-- StarterPlayer/StarterPlayerScripts/Controllers/PetInventoryController.lua
-- ペット専用インベントリUI（ショップ形式）

print("[PetInventoryController] Module loading...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PetConfig"))

print("[PetInventoryController] Module loaded successfully")

local PetInventoryController = {}

-- UI参照
local petFrame
local petButton
local petCards = {}
local selectedPetId = nil

-- 詳細パネルのパーツ
local detailPanel
local detailName
local detailBonus
local detailRarity
local detailSlot1Button
local detailSlot2Button
local detailSlot3Button

-- プレイヤーデータ
local ownedPets = {}
local equippedPets = { "", "", "" }

-- デバウンス
local opening = false

-- 関数前方宣言
local updateUI

-- レアリティ別の色設定
local RARITY_COLORS = {
    Common    = Color3.fromRGB(150, 150, 150),
    Uncommon  = Color3.fromRGB(46, 204, 113),
    Rare      = Color3.fromRGB(52, 152, 219),
    Epic      = Color3.fromRGB(155, 89, 182),
    Legendary = Color3.fromRGB(241, 196, 15),
}

----------------------------------------------------------------
-- UIの初期化
----------------------------------------------------------------
local function setupUI()
	print("[PetInventory] setupUI start")
	local playerGui = player:WaitForChild("PlayerGui")
	local mainHud = playerGui:WaitForChild("MainHud")
	print("[PetInventory] MainHud found:", mainHud:GetFullName())

	-- ボタン管理用ScreenGui
	local sidebarGui = pgui:FindFirstChild("SidebarGui")
	if not sidebarGui then
		sidebarGui = Instance.new("ScreenGui")
		sidebarGui.Name = "SidebarGui"
		sidebarGui.IgnoreGuiInset = true
		sidebarGui.ResetOnSpawn = false
		sidebarGui.Parent = pgui
	end

	-- PetsButton（左側に配置）
	petButton = Instance.new("TextButton")
	petButton.Name = "PetsButton"
	petButton.Size = UDim2.new(0.12, 0, 0.045, 0)
	petButton.Position = UDim2.new(0.02, 0, 0.38, 0) -- Skateboard Shop の下
	petButton.BackgroundColor3 = Color3.fromRGB(155, 89, 182) -- 固定の紫
	petButton.Text = "🐾 PETS"
	petButton.TextColor3 = Color3.new(1, 1, 1)
	petButton.TextScaled = true
	petButton.Font = Enum.Font.FredokaOne
	petButton.Parent = sidebarGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = petButton
	
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = petButton

	-- フレーム
	local oldFrame = playerGui:FindFirstChild("PetInventory")
	if oldFrame then oldFrame:Destroy() end

	petFrame = Instance.new("ScreenGui", playerGui)
	petFrame.Name = "PetInventory"
	petFrame.ResetOnSpawn = false
	petFrame.Enabled = false

	local bg = Instance.new("Frame", petFrame)
	bg.Name = "Background"
	bg.Size = UDim2.new(0, 750, 0, 480)
	bg.Position = UDim2.new(0.5, 0, 0.5, 0)
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.BackgroundColor3 = Color3.fromRGB(160, 230, 50) -- 黄緑テーマ
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 20)
	
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
	
	local uiScale = Instance.new("UIScale", bg)
	local function updateUIScale()
		if not petFrame then return end
		local screenSize = petFrame.AbsoluteSize
		uiScale.Scale = math.min(screenSize.Y / 520, screenSize.X / 790, 1)
	end
	petFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateUIScale)
	updateUIScale()

	local title = Instance.new("TextLabel", bg)
	title.Size = UDim2.new(0, 300, 0, 50)
	title.Position = UDim2.new(0, 20, 0, 15)
	title.BackgroundTransparency = 1
	title.Text = "🐾 ペット装備"
	title.TextColor3 = Color3.fromRGB(30, 30, 30) -- 白色 -> 濃いグレー
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = Instance.new("TextButton", bg)
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 50, 0, 50)
	closeButton.Position = UDim2.new(1, -10, 0, 10)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 30
	Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 12)
	closeButton.Activated:Connect(function() petFrame.Enabled = false end)

	local leftPanel = Instance.new("Frame", bg)
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0.6, -40, 1, -100)
	leftPanel.Position = UDim2.new(0, 20, 0, 80)
	leftPanel.BackgroundTransparency = 1

	local scrollFrame = Instance.new("ScrollingFrame", leftPanel)
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6

	local grid = Instance.new("UIGridLayout", scrollFrame)
	grid.CellSize = UDim2.new(0, 130, 0, 130)
	grid.CellPadding = UDim2.new(0, 10, 0, 10)

	local unequipAllBtn = Instance.new("TextButton", leftPanel)
	unequipAllBtn.Name = "UnequipAllButton"
	unequipAllBtn.Size = UDim2.new(1, 0, 0, 45)
	unequipAllBtn.Position = UDim2.new(0, 0, 1, -5)
	unequipAllBtn.AnchorPoint = Vector2.new(0, 1)
	unequipAllBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	unequipAllBtn.Text = "全て解除"
	unequipAllBtn.TextColor3 = Color3.new(1, 1, 1)
	unequipAllBtn.Font = Enum.Font.GothamBold
	unequipAllBtn.TextSize = 20
	Instance.new("UICorner", unequipAllBtn).CornerRadius = UDim.new(0, 15)
	unequipAllBtn.Activated:Connect(function()
		for i = 1, 3 do Net.Fire("RequestEquipPet", i, "") end
	end)

	detailPanel = Instance.new("Frame", bg)
	detailPanel.Name = "DetailPanel"
	detailPanel.Size = UDim2.new(0.4, -20, 1, -100)
	detailPanel.Position = UDim2.new(0.6, 0, 0, 80)
	detailPanel.BackgroundColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", detailPanel).CornerRadius = UDim.new(0, 20)

	detailName = Instance.new("TextLabel", detailPanel)
	detailName.Size = UDim2.new(1, -20, 0, 30)
	detailName.Position = UDim2.new(0, 10, 0, 10)
	detailName.BackgroundTransparency = 1
	detailName.Text = "ペットを選択"
	detailName.TextColor3 = Color3.new(0, 0, 0)
	detailName.Font = Enum.Font.GothamBold
	detailName.TextSize = 22

	local detailViewport = Instance.new("ViewportFrame", detailPanel)
	detailViewport.Name = "DetailViewport"
	detailViewport.Size = UDim2.new(0.9, 0, 0, 150)
	detailViewport.Position = UDim2.new(0.5, 0, 0, 45)
	detailViewport.AnchorPoint = Vector2.new(0.5, 0)
	detailViewport.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	Instance.new("UICorner", detailViewport).CornerRadius = UDim.new(0, 15)

	detailBonus = Instance.new("TextLabel", detailPanel)
	detailBonus.Size = UDim2.new(1, -40, 0, 35)
	detailBonus.Position = UDim2.new(0, 20, 0, 205)
	detailBonus.BackgroundTransparency = 1
	detailBonus.TextColor3 = Color3.fromRGB(150, 50, 200)
	detailBonus.Font = Enum.Font.GothamBold
	detailBonus.TextSize = 22
	detailBonus.TextXAlignment = Enum.TextXAlignment.Left

	detailRarity = Instance.new("TextLabel", detailPanel)
	detailRarity.Size = UDim2.new(1, -40, 0, 30)
	detailRarity.Position = UDim2.new(0, 20, 0, 240)
	detailRarity.BackgroundTransparency = 1
	detailRarity.TextColor3 = Color3.fromRGB(50, 150, 255)
	detailRarity.Font = Enum.Font.GothamBold
	detailRarity.TextSize = 18
	detailRarity.TextXAlignment = Enum.TextXAlignment.Left

	for i = 1, 3 do
		local slotBtn = Instance.new("TextButton", detailPanel)
		slotBtn.Name = "Slot" .. i
		slotBtn.Size = UDim2.new(0.28, 0, 0, 45)
		slotBtn.Position = UDim2.new(0.04 + (i - 1) * 0.32, 0, 1, -55)
		slotBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
		slotBtn.Text = "Slot " .. i
		slotBtn.TextColor3 = Color3.new(1, 1, 1)
		slotBtn.Font = Enum.Font.GothamBold
		slotBtn.TextSize = 15
		Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 12)
		if i == 1 then detailSlot1Button = slotBtn
		elseif i == 2 then detailSlot2Button = slotBtn
		else detailSlot3Button = slotBtn end
	end
end -- Close the setupUI function

updateUI = function()
	print("[PetInventory] updateUI called")
	if not petFrame then return end
	local scrollFrame = petFrame.Background.LeftPanel.ScrollFrame
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	
	local counts = {}
	for _, pid in ipairs(ownedPets) do counts[pid] = (counts[pid] or 0) + 1 end

	local allIds = PetConfig.GetNewPetIds()
	local rarityRank = { Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5 }
	table.sort(allIds, function(a, b)
		local rA = rarityRank[PetConfig.GetRarity(a)] or 99
		local rB = rarityRank[PetConfig.GetRarity(b)] or 99
		if rA ~= rB then return rA < rB end
		return a < b
	end)

	for _, petId in ipairs(allIds) do
		local count = counts[petId] or 0
		if count > 0 then
			local rarity = PetConfig.GetRarity(petId)
			local displayName = PetConfig.GetDisplayName(petId)
			local modelId = PetConfig.GetModelId(petId)

			local card = Instance.new("TextButton", scrollFrame)
			card.Size = UDim2.new(0, 130, 0, 130)
			card.BackgroundColor3 = RARITY_COLORS[rarity] or RARITY_COLORS.Common
			card.Text = ""
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 15)
			
			local viewport = Instance.new("ViewportFrame", card)
			viewport.Size = UDim2.new(1, 0, 0.75, 0)
			viewport.Position = UDim2.new(0, 0, 0.15, 0)
			viewport.BackgroundTransparency = 1
			
			local Models = ReplicatedStorage:FindFirstChild("Models")
			local PetModels = Models and Models:FindFirstChild("Pets")
			local petTemplate = PetModels and PetModels:FindFirstChild(modelId)
			if petTemplate then
				local camera = Instance.new("Camera")
				viewport.CurrentCamera = camera
				camera.Parent = viewport
				
				local petClone = petTemplate:Clone()
				petClone:PivotTo(CFrame.new(0, 0, 0))
				petClone.Parent = viewport
				
				task.delay(0.01, function()
					if not petClone or not camera then return end
					local cf, size = petClone:GetBoundingBox()
					local radius = size.Magnitude / 2
					-- 計算された距離 (FOV 70基準)
					local dist = radius / 0.7
					camera.CFrame = CFrame.new(cf.Position + Vector3.new(dist * 0.6, dist * 0.4, -dist), cf.Position)
				end)
			end

			local nameLabel = Instance.new("TextLabel", card)
			nameLabel.Size = UDim2.new(1, 0, 0, 25)
			nameLabel.BackgroundColor3 = Color3.new(0, 0, 0)
			nameLabel.BackgroundTransparency = 0.5
			nameLabel.Text = displayName .. (count > 1 and " x" .. count or "")
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextSize = 14
			nameLabel.Font = Enum.Font.GothamBold

			local equippedCount = 0
			for i=1,3 do if equippedPets[i] == petId then equippedCount = equippedCount + 1 end end
			if equippedCount > 0 then
				local eqLabel = Instance.new("TextLabel", card)
				eqLabel.Size = UDim2.new(1, 0, 0, 25)
				eqLabel.Position = UDim2.new(0, 0, 1, -25)
				eqLabel.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
				eqLabel.Text = "EQUIPPED"
				eqLabel.TextColor3 = Color3.new(1, 1, 1)
				eqLabel.Font = Enum.Font.GothamBold
			end

			card.Activated:Connect(function()
				selectedPetId = petId
				print("[PetInventory] Selected pet:", petId)
				updateUI()
			end)
		end
	end

	-- 詳細更新
	if selectedPetId and counts[selectedPetId] and counts[selectedPetId] > 0 then
		detailName.Text = PetConfig.GetDisplayName(selectedPetId)
		detailBonus.Text = string.format("💰 BONUS: +%.1f%%", PetConfig.GetBonus(selectedPetId) * 100)
		detailRarity.Text = "⭐ RARITY: " .. PetConfig.GetRarity(selectedPetId)
		
		-- 詳細の3Dモデル表示
		local detailViewport = detailPanel:FindFirstChild("DetailViewport")
		if detailViewport then
			detailViewport:ClearAllChildren()
			local Models = ReplicatedStorage:FindFirstChild("Models")
			local PetModels = Models and Models:FindFirstChild("Pets")
			local modelId = PetConfig.GetModelId(selectedPetId)
			local petTemplate = PetModels and PetModels:FindFirstChild(modelId)
			
			if petTemplate then
				local cam = Instance.new("Camera")
				detailViewport.CurrentCamera = cam
				cam.Parent = detailViewport
				
				local petClone = petTemplate:Clone()
				petClone:PivotTo(CFrame.new(0, 0, 0))
				petClone.Parent = detailViewport
				
				task.delay(0.05, function()
					if not petClone or not cam then return end
					local cf, size = petClone:GetBoundingBox()
					local radius = size.Magnitude / 2
					local dist = radius / 0.7
					cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist * 0.5, dist * 0.4, -dist), cf.Position)
				end)
			end
		end

		for slot = 1, 3 do
			local btn = (slot == 1) and detailSlot1Button or (slot == 2) and detailSlot2Button or detailSlot3Button
			local isEq = (equippedPets[slot] == selectedPetId)
			btn.Text = isEq and "UNEQUIP" or "EQUIP " .. slot
			btn.BackgroundColor3 = isEq and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(0, 200, 50)
		end
	else
		-- 未選択状態
		detailName.Text = "SELECT A PET"
		detailBonus.Text = ""
		detailRarity.Text = ""
		local detailViewport = detailPanel:FindFirstChild("DetailViewport")
		if detailViewport then detailViewport:ClearAllChildren() end
		for slot = 1, 3 do
			local btn = (slot == 1) and detailSlot1Button or (slot == 2) and detailSlot2Button or detailSlot3Button
			btn.Text = "SLOT " .. slot
			btn.BackgroundColor3 = Color3.fromRGB(180, 180, 190) -- 50,50,50 -> 明るいグレー
		end
	end
end

local function onSync(payload)
	if not payload then return end
	if payload.ownedPets then ownedPets = payload.ownedPets end
	if payload.equippedPets then equippedPets = payload.equippedPets end
	updateUI()
end

function PetInventoryController.Init()
	print("[PetInventoryController] Init v4")
	setupUI() -- ここでボタンとUIを生成
	
	-- スロットボタンのクリック登録
	for i = 1, 3 do
		local btn = (i == 1) and detailSlot1Button or (i == 2) and detailSlot2Button or detailSlot3Button
		btn.Activated:Connect(function()
			if not selectedPetId or selectedPetId == "" then return end
			local isEq = (equippedPets[i] == selectedPetId)
			print("[PetInventory] Equip requested for slot", i, "pet:", selectedPetId)
			Net.Fire("RequestEquipPet", i, isEq and "" or selectedPetId)
		end)
	end

	-- ペットボタンのクリック登録
	if petButton then
		petButton.Activated:Connect(function()
			if opening then return end
			opening = true
			print("[PetInventory] PetsButton Activated")
			if not petFrame.Enabled then
				local data = Net.Invoke("RequestPetInventory")
				onSync(data)
			end
			petFrame.Enabled = not petFrame.Enabled
			task.delay(0.3, function() opening = false end)
		end)
	else
		warn("[PetInventory] PetsButton not found after setupUI!")
	end
	
	Net.On("PetInventorySync", onSync)
end

return PetInventoryController
