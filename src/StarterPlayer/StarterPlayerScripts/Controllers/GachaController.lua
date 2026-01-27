local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))
local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PetConfig"))

local player = game:GetService("Players").LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

local GachaController = {}

-- UI参照
local gachaPanel = nil
local gachaShopButton = nil
local effectPanel = nil
local initialized = false -- 初期化済みフラグ
local isRolling = false -- 演出中フラグ

local unlockedTiers = { BASIC = true } -- 初期状態

local function getHud()
	local pg = player:WaitForChild("PlayerGui", 10)
	if not pg then return nil end
	return pg:WaitForChild("MainHud", 10)
end

-- ティア別の鮮やかな色設定 (アンロック時)
local TIER_COLORS = {
	BASIC  = Color3.fromRGB(46, 204, 113),  -- Vivid Green
	RARE   = Color3.fromRGB(52, 152, 219),  -- Vivid Blue
	LEGEND = Color3.fromRGB(241, 196, 15),  -- Vivid Gold/Yellow
}
local LOCKED_COLOR = Color3.fromRGB(60, 60, 65) -- 沈んだグレー

-- レアリティ別の色設定
local RARITY_COLORS = {
	Common    = Color3.fromRGB(189, 195, 199),
	Uncommon  = Color3.fromRGB(46, 204, 113),
	Rare      = Color3.fromRGB(52, 152, 219),
	Epic      = Color3.fromRGB(155, 89, 182),
	Legendary = Color3.fromRGB(241, 196, 15),
}

-- UIの状態（ボタンのテキストと色）を更新
local function updateButtonStates(buttons)
	for tier, btn in pairs(buttons) do
		if not btn then continue end
		
		local isUnlocked = unlockedTiers[tier]
		local tierColor = TIER_COLORS[tier] or TIER_COLORS.BASIC
		
		btn.BackgroundColor3 = isUnlocked and tierColor or LOCKED_COLOR
		btn.AutoButtonColor = isUnlocked and not isRolling

		if isUnlocked then
			btn.Text = "ROLL"
		else
			local rule = GameConfig.GachaTierRules[tier]
			if rule and rule.cansSmashedTotal then
				btn.Text = string.format("LOCKED (%d)", rule.cansSmashedTotal)
			else
				btn.Text = "LOCKED"
			end
		end
	end
end

----------------------------------------------------------------
-- ルーレット演出ロジック
----------------------------------------------------------------
local function playGachaEffect(targetPetId, callback)
	if not effectPanel then return callback() end
	
	isRolling = true
	effectPanel.Visible = true
	
	local petList = {}
	for id, _ in pairs(PetConfig.All) do
		if not id:find("Pet_") then continue end -- ペットIDのみ抽出
		table.insert(petList, id)
	end

	local shuffleLabel = effectPanel:FindFirstChild("ShuffleLabel")
	local bg = effectPanel:FindFirstChild("EffectBG")
	
	-- 演出アニメーション (高速シャッフル)
	local duration = 1.5
	local startTime = os.clock()
	local waitTime = 0.05
	
	while os.clock() - startTime < duration do
		local randomId = petList[math.random(#petList)]
		local petConf = PetConfig.All[tostring(randomId)]
		if petConf and shuffleLabel then
			shuffleLabel.Text = petConf.displayName or randomId
			bg.BackgroundColor3 = RARITY_COLORS[petConf.rarity] or RARITY_COLORS.Common
		end
		task.wait(waitTime)
		waitTime = waitTime * 1.1 -- 徐々に遅くする
	end

	-- 最終結果を表示
	local finalPet = PetConfig.All[tostring(targetPetId)]
	if finalPet and shuffleLabel then
		shuffleLabel.Text = finalPet.displayName or targetPetId
		bg.BackgroundColor3 = RARITY_COLORS[finalPet.rarity] or RARITY_COLORS.Common
	end
	
	task.wait(0.5)
	effectPanel.Visible = false
	isRolling = false
	callback()
end

----------------------------------------------------------------
-- 共通：ガチャパネルを開く
----------------------------------------------------------------
local function openGachaPanel()
	if not gachaPanel then return end
	gachaPanel.Visible = true
end

----------------------------------------------------------------
-- ワールドのトリガー
----------------------------------------------------------------
local function bindWorldTrigger()
	task.wait(2)
	local ok, worldShop = pcall(function() return workspace:WaitForChild("shop", 30) end)
	if not ok or not worldShop then return end
	local petShop = worldShop:FindFirstChild("petShop")
	if not petShop then return end
	local trigger = petShop:FindFirstChild("Trigger", true)
	if not trigger then return end
	local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(p)
		if p ~= player then return end
		openGachaPanel()
	end)
end

function GachaController.Init()
	if initialized then return end
	initialized = true

	local RequestGacha = Net.E("RequestGacha")
	local GachaResult  = Net.E("GachaResult")
	local UnlockStateSync = Net.E("UnlockStateSync")

	task.spawn(function()
		local hud = getHud()
		if not hud then return end

		-- ボタン管理用ScreenGui
		local sidebarGui = pgui:FindFirstChild("SidebarGui")
		if not sidebarGui then
			sidebarGui = Instance.new("ScreenGui")
			sidebarGui.Name = "SidebarGui"
			sidebarGui.IgnoreGuiInset = true
			sidebarGui.ResetOnSpawn = false
			sidebarGui.Parent = pgui
		end

		-- ガチャショップボタン
		gachaShopButton = Instance.new("TextButton")
		gachaShopButton.Name = "GachaShopButton"
		gachaShopButton.Size = UDim2.new(0.12, 0, 0.045, 0)
		gachaShopButton.Position = UDim2.new(0.02, 0, 0.44, 0) -- Pet Inventory の下
		gachaShopButton.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
		gachaShopButton.Text = "🎰 GACHA"
		gachaShopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		gachaShopButton.TextScaled = true
		gachaShopButton.Font = Enum.Font.FredokaOne
		gachaShopButton.Parent = sidebarGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = gachaShopButton
		
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Parent = gachaShopButton

		local gachaGui = pgui:FindFirstChild("GachaGui")
		if not gachaGui then
			gachaGui = Instance.new("ScreenGui")
			gachaGui.Name = "GachaGui"
			gachaGui.IgnoreGuiInset = false -- 他のショップに合わせる
			gachaGui.ResetOnSpawn = false
			gachaGui.Parent = pgui
		end

		gachaPanel = gachaGui:FindFirstChild("GachaPanel")
		if not gachaPanel then
			gachaPanel = Instance.new("Frame")
			gachaPanel.Name = "GachaPanel"
			gachaPanel.Size = UDim2.new(0, 750, 0, 480) -- サイズ統一
			gachaPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
			gachaPanel.AnchorPoint = Vector2.new(0.5, 0.5)
			gachaPanel.BackgroundColor3 = Color3.fromRGB(160, 230, 50) -- 黄緑テーマ
			gachaPanel.Visible = false
			gachaPanel.ZIndex = 100
			gachaPanel.Parent = gachaGui
			Instance.new("UICorner", gachaPanel).CornerRadius = UDim.new(0, 20)
			
			-- 太い黒枠線
			local bgStroke = Instance.new("UIStroke", gachaPanel)
			bgStroke.Thickness = 4
			bgStroke.Color = Color3.fromRGB(0, 0, 0)
			bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			
			-- 内側の白い枠線（アクセント）
			local innerStroke = Instance.new("UIStroke", gachaPanel)
			innerStroke.Thickness = 1.5
			innerStroke.Color = Color3.fromRGB(255, 255, 255)
			innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			
			local uiScale = Instance.new("UIScale", gachaPanel)
			local function updateUIScale()
				if not gachaGui then return end
				local screenSize = gachaGui.AbsoluteSize
				local scaleH = math.min(1, screenSize.Y / (480 + 40))
				local scaleW = math.min(1, screenSize.X / (750 + 40))
				uiScale.Scale = math.min(scaleH, scaleW)
			end
			gachaGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateUIScale)
			updateUIScale()
			
			local title = Instance.new("TextLabel", gachaPanel)
			title.Size = UDim2.new(1, -40, 0, 50)
			title.Position = UDim2.new(0, 20, 0, 10)
			title.BackgroundTransparency = 1
			title.Text = "ペットガチャ"
			title.TextSize = 32
			title.TextColor3 = Color3.fromRGB(30, 30, 30)
			title.Font = Enum.Font.GothamBold
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.ZIndex = 101
			
			local closeButton = Instance.new("TextButton", gachaPanel)
			closeButton.Name = "CloseButton"
			closeButton.Size = UDim2.new(0, 50, 0, 50)
			closeButton.Position = UDim2.new(1, -60, 0, 10)
			closeButton.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
			closeButton.Text = "X"
			closeButton.TextSize = 28
			closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			closeButton.Font = Enum.Font.GothamBold
			closeButton.ZIndex = 105
			Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 12)
		end
		
		-- 演出用パネル
		effectPanel = gachaPanel:FindFirstChild("EffectPanel")
		if not effectPanel then
			effectPanel = Instance.new("Frame", gachaPanel)
			effectPanel.Name = "EffectPanel"
			effectPanel.Size = UDim2.new(1, 0, 1, 0)
			effectPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			effectPanel.BackgroundTransparency = 0.5
			effectPanel.Visible = false
			effectPanel.ZIndex = 200
			
			Instance.new("UICorner", effectPanel).CornerRadius = UDim.new(0, 20)

			local bg = Instance.new("Frame", effectPanel)
			bg.Name = "EffectBG"
			bg.Size = UDim2.new(0, 400, 0, 150)
			bg.Position = UDim2.new(0.5, 0, 0.5, 0)
			bg.AnchorPoint = Vector2.new(0.5, 0.5)
			bg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			bg.ZIndex = 201
			Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
			
			local sLabel = Instance.new("TextLabel", bg)
			sLabel.Name = "ShuffleLabel"
			sLabel.Size = UDim2.new(1, 0, 1, 0)
			sLabel.BackgroundTransparency = 1
			sLabel.Text = "???"
			sLabel.TextSize = 40
			sLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			sLabel.Font = Enum.Font.GothamBold
			sLabel.ZIndex = 202
			
			local stroke = Instance.new("UIStroke", sLabel)
			stroke.Thickness = 3
			stroke.Color = Color3.fromRGB(0, 0, 0)
		end

		-- ティアカード
		local buttons = {}
		local tiers = {"BASIC", "RARE", "LEGEND"}
		for i, tier in ipairs(tiers) do
			local old = gachaPanel:FindFirstChild(tier .. "Card")
			if old then old:Destroy() end
			
			local tierConf = PetConfig.Tiers[tier] or { cost = 0 }
			local tierColor = TIER_COLORS[tier] or TIER_COLORS.BASIC

			local card = Instance.new("Frame", gachaPanel)
			card.Name = tier .. "Card"
			card.Size = UDim2.new(0, 200, 0, 280) -- 少し小さくして余白を確保
			card.Position = UDim2.new(0, 45 + (i-1) * 230, 0, 90)
			card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			card.ZIndex = 101
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
			
			-- カードの枠線
			local cardStroke = Instance.new("UIStroke", card)
			cardStroke.Thickness = 2
			cardStroke.Color = Color3.fromRGB(0, 0, 0)
				
			local img = Instance.new("ViewportFrame", card) -- ViewportFrameに変更
			img.Name = "PetPreview"
			img.Size = UDim2.new(1, -20, 0, 150)
			img.Position = UDim2.new(0, 10, 0, 10)
			img.BackgroundColor3 = tierColor
			img.BackgroundTransparency = 0.5
			img.ZIndex = 102
			Instance.new("UICorner", img).CornerRadius = UDim.new(0, 12)
			
			-- 代表ペットの表示設定
			local previewPetId = (tier == "BASIC") and "Pet_Starter" or (tier == "RARE") and "Pet_Crystal" or "Pet_Cosmic"
			task.spawn(function()
				local Models = ReplicatedStorage:WaitForChild("Models", 5)
				local PetModels = Models and Models:WaitForChild("Pets", 5)
				local petTemplate = PetModels and PetModels:FindFirstChild(previewPetId)
				if petTemplate then
					local clone = petTemplate:Clone()
					clone:PivotTo(CFrame.new(0, 0, 0))
					clone.Parent = img

					local cam = Instance.new("Camera")
					img.CurrentCamera = cam
					cam.Parent = img

					-- 僅かに待機して位置を確定させる
					task.delay(0.03, function()
						if not clone or not cam then return end
						local cf, size = clone:GetBoundingBox()
						local radius = size.Magnitude / 2
						local dist = radius / math.tan(math.rad(cam.FieldOfView / 3))
						cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist * 0.6, dist * 0.4, dist * 0.8), cf.Position)
					end)
				end
			end)
			
			local tl = Instance.new("TextLabel", card)
			tl.Size = UDim2.new(1, 0, 0, 30)
			tl.Position = UDim2.new(0, 0, 0, 140)
			tl.BackgroundTransparency = 1
			tl.Text = tier
			tl.TextSize = 22
			tl.TextColor3 = tierColor
			tl.Font = Enum.Font.GothamBold
			tl.ZIndex = 102
				
			local cl = Instance.new("TextLabel", card)
			cl.Size = UDim2.new(1, 0, 0, 25)
			cl.Position = UDim2.new(0, 0, 0, 175)
			cl.BackgroundTransparency = 1
			cl.Text = string.format("%d SCRAP", tierConf.cost)
			cl.TextSize = 18
			cl.TextColor3 = Color3.fromRGB(50, 50, 50)
			cl.Font = Enum.Font.GothamSemibold
			cl.ZIndex = 102
				
			local rb = Instance.new("TextButton", card)
			rb.Name = "RollButton"
			rb.Size = UDim2.new(1, -20, 0, 45)
			rb.Position = UDim2.new(0, 10, 1, -55)
			rb.BackgroundColor3 = tierColor
			rb.TextSize = 18
			rb.TextColor3 = Color3.fromRGB(255, 255, 255)
			rb.Font = Enum.Font.GothamBold
			rb.ZIndex = 102
			Instance.new("UICorner", rb).CornerRadius = UDim.new(0, 10)
			buttons[tier] = rb
		end

		-- 結果パネル
		local resultPanel = gachaPanel:FindFirstChild("ResultPanel")
		if not resultPanel then
			resultPanel = Instance.new("Frame", gachaPanel)
			resultPanel.Name = "ResultPanel"
			resultPanel.Size = UDim2.new(0, 350, 0, 380)
			resultPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
			resultPanel.AnchorPoint = Vector2.new(0.5, 0.5)
			resultPanel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			resultPanel.Visible = false
			resultPanel.ZIndex = 300
			Instance.new("UICorner", resultPanel).CornerRadius = UDim.new(0, 24)
			
			local pImg = Instance.new("ViewportFrame", resultPanel)
			pImg.Name = "PetImage"
			pImg.Size = UDim2.new(1, -40, 0, 200)
			pImg.Position = UDim2.new(0, 20, 0, 20)
			pImg.BackgroundTransparency = 1
			pImg.ZIndex = 301
			Instance.new("UICorner", pImg).CornerRadius = UDim.new(0, 16)
			
			local cam = Instance.new("Camera", pImg)
			pImg.CurrentCamera = cam
			
			local pName = Instance.new("TextLabel", resultPanel)
			pName.Name = "PetNameLabel"
			pName.Size = UDim2.new(1, 0, 0, 40)
			pName.Position = UDim2.new(0, 0, 0, 230)
			pName.BackgroundTransparency = 1
			pName.TextSize = 28
			pName.Font = Enum.Font.GothamBold
			pName.ZIndex = 301
			
			local rLbl = Instance.new("TextLabel", resultPanel)
			rLbl.Name = "RarityLabel"
			rLbl.Size = UDim2.new(1, 0, 0, 30)
			rLbl.Position = UDim2.new(0, 0, 0, 270)
			rLbl.BackgroundTransparency = 1
			rLbl.TextSize = 20
			rLbl.ZIndex = 301
			
			local rClose = Instance.new("TextButton", resultPanel)
			rClose.Name = "ResultCloseButton"
			rClose.Size = UDim2.new(1, -40, 0, 50)
			rClose.Position = UDim2.new(0, 20, 1, -65)
			rClose.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
			rClose.Text = "OK"
			rClose.TextSize = 22
			rClose.TextColor3 = Color3.fromRGB(255, 255, 255)
			rClose.Font = Enum.Font.GothamBold
			rClose.ZIndex = 301
			Instance.new("UICorner", rClose).CornerRadius = UDim.new(0, 12)
			rClose.Activated:Connect(function() resultPanel.Visible = false end)
		end

		-- バインド
		gachaShopButton.Activated:Connect(function() gachaPanel.Visible = not gachaPanel.Visible end)
		
		local cBtn = gachaPanel:FindFirstChild("CloseButton")
		if cBtn then
			cBtn.Activated:Connect(function() gachaPanel.Visible = false end)
		end

		for tier, btn in pairs(buttons) do
			btn.Activated:Connect(function()
				if isRolling or not unlockedTiers[tier] then return end
				if RequestGacha then RequestGacha:FireServer(tier) end
				updateButtonStates(buttons) -- 即座にボタンを無効化
			end)
		end

		updateButtonStates(buttons)

		if UnlockStateSync then
			UnlockStateSync.OnClientEvent:Connect(function(payload)
				if payload and payload.gachaTiers then
					unlockedTiers = payload.gachaTiers
					updateButtonStates(buttons)
				end
			end)
		end

		if GachaResult then
			GachaResult.OnClientEvent:Connect(function(payload)
				if not payload.ok then 
					isRolling = false
					updateButtonStates(buttons)
					return 
				end
				playGachaEffect(payload.petId, function()
					local petConf = PetConfig.All[tostring(payload.petId)] or {}
					local modelId = PetConfig.GetModelId(payload.petId)
					
					resultPanel.PetNameLabel.Text = petConf.displayName or payload.petId
					resultPanel.RarityLabel.Text = string.format("%s - %s", petConf.rarity or "Common", payload.isNew and "NEW!" or "Duplicate")
					
					-- 3Dモデル表示の更新
					local pImg = resultPanel:FindFirstChild("PetImage")
					if pImg and pImg:IsA("ViewportFrame") then
						pImg:ClearAllChildren()
						
						local Models = ReplicatedStorage:FindFirstChild("Models")
						local PetModels = Models and Models:FindFirstChild("Pets")
						local petTemplate = PetModels and PetModels:FindFirstChild(modelId)
						
						if petTemplate then
							local petClone = petTemplate:Clone()
							petClone:PivotTo(CFrame.new(0, 0, 0))
							petClone.Parent = pImg
							
							local camera = Instance.new("Camera")
							pImg.CurrentCamera = camera
							camera.Parent = pImg
							
							-- 結果表示は確実性を期すため少し長めに待つ
							task.delay(0.05, function()
								if not petClone or not camera then return end
								local cf, size = petClone:GetBoundingBox()
								local radius = size.Magnitude / 2
								-- FOV 70 に対して適切な距離を計算 (math.tan(35deg) approx 0.7)
								local dist = radius / 0.7
								camera.CFrame = CFrame.new(cf.Position + Vector3.new(dist * 0.5, dist * 0.4, -dist), cf.Position)
							end)
						end
						
						-- 背景色の設定（レアリティに合わせるが、透明度を調整）
						local rarityColor = RARITY_COLORS[petConf.rarity] or RARITY_COLORS.Common
						local bg = Instance.new("Frame", pImg)
						bg.Name = "Background"
						bg.Size = UDim2.new(1, 0, 1, 0)
						bg.BackgroundColor3 = rarityColor
						bg.BackgroundTransparency = 0.7
						bg.ZIndex = pImg.ZIndex - 1
						Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
					end
					
					resultPanel.Visible = true
					updateButtonStates(buttons) -- ボタンを復帰
				end)
			end)
		end
		
		bindWorldTrigger()
	end)
end

return GachaController
