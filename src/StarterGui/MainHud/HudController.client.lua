-- HudController.client.lua
-- Hammer selection and unlock logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))

local gui = script.Parent

-- [STEP 0] UI References
-- ScoreController が作成する MainHud_Modern を優先し、なければ script.Parent (MainHud) を使用
local targetGui = gui:WaitForChild("MainHud_Modern", 5) or gui
local hammerPanel = targetGui:WaitForChild("HammerPanel", 5)

if not hammerPanel then
	warn("[HudController] HammerPanel not found. Creating a fallback container.")
	hammerPanel = Instance.new("Frame")
	hammerPanel.Name = "HammerPanel"
	hammerPanel.Size = UDim2.new(0.6, 0, 0.1, 0)
	hammerPanel.Position = UDim2.new(0.2, 0, 0.85, 0)
	hammerPanel.BackgroundTransparency = 1
	hammerPanel.Parent = targetGui
end

local statusLabel = hammerPanel:FindFirstChild("StatusLabel")
if not statusLabel then
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(0.3, 0, 1, 0)
	statusLabel.Position = UDim2.new(0, 0, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.FredokaOne
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextScaled = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = hammerPanel
end
-- Reparent Buttons
local buttonNames = {"Button_Basic", "Button_Shockwave", "Button_Multi", "Button_Hybrid", "Button_Master"}
for _, bName in ipairs(buttonNames) do
	local btn = gui:FindFirstChild(bName, true)
	if btn then
		btn.Parent = hammerPanel
		print("[HudController] Reparented button to HammerPanel:", bName)
	end
end

-- Add layout to HammerPanel if it's our fallback
if not hammerPanel:FindFirstChildOfClass("UIListLayout") then
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = hammerPanel
end

-- Find Gacha/Pets
local gachaPanel = gui:WaitForChild("GachaPanel", 5)
if gachaPanel then
	local petsButton = gachaPanel:FindFirstChild("PetsButton")
	if petsButton then
		print("[HudController] Found Pets button")
	end
end

-- Mapping Hammer IDs to Buttons
local HammerButtons = {
	BASIC = targetGui:FindFirstChild("Button_Basic", true),
	SHOCKWAVE = targetGui:FindFirstChild("Button_Shockwave", true),
	MULTI = targetGui:FindFirstChild("Button_Multi", true),
	HYBRID = targetGui:FindFirstChild("Button_Hybrid", true),
	MASTER = targetGui:FindFirstChild("Button_Master", true),
}

local function forceEquip(hammerId)
	print("[HudController] Attempting to equip:", hammerId)

	-- HammerShopServiceのEquipHammer関数を呼び出し
	local EquipHammerFunc = Net.F(Constants.Functions.EquipHammer)
	local result = EquipHammerFunc:InvokeServer(hammerId)

	if result and result.success then
		print("[HudController] Successfully equipped:", hammerId)
	else
		warn("[HudController] Failed to equip:", hammerId)
	end
end

local boundButtons = {}
local function bindButtons()
	for hammerId, btn in pairs(HammerButtons) do
		if btn and not boundButtons[btn] then
			boundButtons[btn] = true
			btn.Activated:Connect(function()
				forceEquip(hammerId)
			end)
			print("[HudController] Bound button for:", hammerId)
		end
	end
end

local function updateStatusLabel(hammerType)
	local lbl = statusLabel
	if lbl then
		lbl.Text = "EQUIPPED:\n" .. tostring(hammerType)
	end
end

Net.On(Constants.Events.EquipHammerRequest, function(hammerType)
	print("[HudController] EquipHammerRequest received:", hammerType)
	updateStatusLabel(hammerType)
end)

player:GetAttributeChangedSignal("EquippedHammer"):Connect(function()
	updateStatusLabel(player:GetAttribute("EquippedHammer"))
end)
updateStatusLabel(player:GetAttribute("EquippedHammer") or "NONE")

-- ハンマーアンロック表示ロジック - ハンマーショップ導入により無効化
--[[
local function applyHammerUnlockState(state)
    if not state or not state.hammers then return end
    lastUnlockState = state
    print("[HudController] Applying unlock state")

    local hRules = GameConfig.HammerUnlockRules or {}
    local TweenService = game:GetService("TweenService")

    for hammerId, button in pairs(HammerButtons) do
        if button then
            local unlocked = state.hammers[hammerId]
            local labelCondition = button:FindFirstChild("Label_Condition")
            local labelName = button:FindFirstChild("Label_Name") or button:FindFirstChildOfClass("TextLabel")
            local hoverScale = button:FindFirstChild("HoverScale")

            if unlocked then
                button.AutoButtonColor = true
                button.BackgroundTransparency = 0
                button.Text = button.Text:gsub(" 🔒", "")
                if labelCondition then labelCondition.Visible = false end
                
                if not hoverScale then
                    hoverScale = Instance.new("UIScale")
                    hoverScale.Name = "HoverScale"
                    hoverScale.Scale = 1
                    hoverScale.Parent = button
                end
                
                button.MouseEnter:Connect(function()
                    TweenService:Create(hoverScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
                end)
                button.MouseLeave:Connect(function()
                    TweenService:Create(hoverScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
                end)
                
                if labelName then
                    labelName.TextColor3 = Color3.fromRGB(255, 255, 255)
                end
            else
                button.AutoButtonColor = false
                button.BackgroundTransparency = 0.4
                if not button.Text:find("🔒") then
                    button.Text = button.Text .. " 🔒"
                end
                if labelCondition then
                    labelCondition.Visible = true
                    labelCondition.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
                if hoverScale then hoverScale:Destroy() end
                if labelName then
                    labelName.TextColor3 = Color3.fromRGB(180, 180, 180)
                end
            end
        end
    end
end

UnlockStateSync.OnClientEvent:Connect(applyHammerUnlockState)
--]]
bindButtons()
print("[HudController] boot:", script:GetFullName())
