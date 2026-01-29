-- HudController.client.lua
-- Hammer selection and unlock logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local SetEquippedHammer = Net.E("SetEquippedHammer")
local EquipHammerRequest = Net.E("EquipHammerRequest")
local ScoreChanged = Net.E("ScoreChanged")
local UnlockStateSync = Net.E("UnlockStateSync")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local UnlockText = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UnlockText"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))

local gui = script.Parent

-- [STEP 0] UI References
local function ensureHammerPanel()
    local panel = gui:FindFirstChild("HammerPanel")
    if not panel then
        warn("[HudController] HammerPanel missing! Creating fallback...")
        panel = Instance.new("Frame")
        panel.Name = "HammerPanel"
        panel.Size = UDim2.new(0.3, 0, 0.5, 0)
        panel.Position = UDim2.new(0.98, 0, 0.5, 0)
        panel.AnchorPoint = Vector2.new(1, 0.5)
        panel.BackgroundTransparency = 0.5
        panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        panel.Parent = gui
        
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.Parent = panel
        
        Instance.new("UICorner", panel)
    end
    return panel
end

local hammerPanel = ensureHammerPanel()
local statusLabel = hammerPanel:FindFirstChild("StatusLabel")
if not statusLabel then
    statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, 0, 0, 40)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.Font = Enum.Font.FredokaOne
    statusLabel.TextScaled = true
    statusLabel.Parent = hammerPanel
end

-- Reparent Buttons or Create Fallbacks
local buttonNames = {
    BASIC = "Button_Basic",
    SHOCKWAVE = "Button_Shockwave",
    MULTI = "Button_Multi",
    HYBRID = "Button_Hybrid",
    MASTER = "Button_Master"
}

for hammerId, bName in pairs(buttonNames) do
    local btn = gui:FindFirstChild(bName, true)
    if not btn then
        warn("[HudController] Creating fallback button for:", hammerId)
        btn = Instance.new("TextButton")
        btn.Name = bName
        btn.Size = UDim2.new(1, 0, 0, 35)
        btn.Text = hammerId
        btn.Parent = hammerPanel
        Instance.new("UICorner", btn)
    elseif btn.Parent ~= hammerPanel then
        btn.Parent = hammerPanel
    end
end

-- Find Gacha/Pets
local gachaPanel = gui:WaitForChild("GachaPanel", 5)
if gachaPanel then
    local petsButton = gachaPanel:FindFirstChild("PetsButton")
    if petsButton then
        print("[HudController] Found Pets button")
    end
end

-- Mapping Hammer IDs to Buttons (Recursive Search)
local HammerButtons = {
    BASIC = gui:FindFirstChild("Button_Basic", true),
    SHOCKWAVE = gui:FindFirstChild("Button_Shockwave", true),
    MULTI = gui:FindFirstChild("Button_Multi", true),
    HYBRID = gui:FindFirstChild("Button_Hybrid", true),
    MASTER = gui:FindFirstChild("Button_Master", true),
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
    local lbl = gui:FindFirstChild("StatusLabel", true) 
    if lbl then
        lbl.Text = "EQUIPPED:\n" .. tostring(hammerType)
    end
end

EquipHammerRequest.OnClientEvent:Connect(function(hammerType)
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
