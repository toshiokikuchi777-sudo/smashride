-- HudController.client.lua
-- Hammer selection and unlock logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetEquippedHammer = Remotes:WaitForChild("SetEquippedHammer")
local EquipHammerRequest = Remotes:WaitForChild("EquipHammerRequest")
local ScoreChanged = Remotes:WaitForChild("ScoreChanged")
local UnlockStateSync = Remotes:WaitForChild("UnlockStateSync")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local UnlockText = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UnlockText"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))

local gui = script.Parent

-- [STEP 0] UI References
local hammerPanel = gui:WaitForChild("HammerPanel")
local statusLabel = hammerPanel:FindFirstChild("StatusLabel") or gui:FindFirstChild("StatusLabel", true)

-- Reparent Buttons
local buttonNames = {"Button_Basic", "Button_Shockwave", "Button_Multi", "Button_Hybrid", "Button_Master"}
for _, bName in ipairs(buttonNames) do
    local btn = gui:FindFirstChild(bName, true)
    if btn and btn.Parent == statusLabel then
        btn.Parent = hammerPanel
        print("[HudController] Reparented button to HammerPanel:", bName)
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

-- Mapping Hammer IDs to Buttons
local HammerButtons = {
    BASIC = gui:FindFirstChild("Button_Basic", true),
    SHOCKWAVE = gui:FindFirstChild("Button_Shockwave", true),
    MULTI = gui:FindFirstChild("Button_Multi", true),
    HYBRID = gui:FindFirstChild("Button_Hybrid", true),
    MASTER = gui:FindFirstChild("Button_Master", true),
}

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

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
