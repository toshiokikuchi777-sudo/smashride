-- StarterGui/MainHud/SpawnController.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local RE_RequestSpawn = Net.E(Constants.Events.RequestSpawn)

local gui = script.Parent
local function updateHomeButtonText(btn, text)
    if not btn then return end
    local label = btn:FindFirstChild("Label")
    if label then
        label.Text = text
    else
        btn.Text = text
    end
end

local function ensureHomeButton()
    local btn = gui:FindFirstChild("HomeButton", true)
    if not btn then
        warn("[SpawnController] HomeButton missing! Creating fallback...")
        btn = Instance.new("TextButton")
        btn.Name = "HomeButton"
        btn.Size = UDim2.new(0, 100, 0, 40)
        btn.Position = UDim2.new(0.5, -50, 0.9, 0) -- 画面下部中央
        btn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
        updateHomeButtonText(btn, "🏠 HOME")
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.FredokaOne
        btn.Parent = gui
        Instance.new("UICorner", btn)
    else
        -- Ensure initial text is set correctly if using Label
        updateHomeButtonText(btn, "🏠 SPAWN")
    end
    return btn
end

local homeButton = ensureHomeButton()

local isCooldown = false
local COOLDOWN_TIME = 3.0

homeButton.Activated:Connect(function()
    if isCooldown then return end
    
    print("[SpawnController] Sending spawn request")
    RE_RequestSpawn:FireServer()
    
    -- クールダウン処理
    isCooldown = true
    homeButton.AutoButtonColor = false
    homeButton.BackgroundTransparency = 0.5
    
    task.delay(COOLDOWN_TIME, function()
        isCooldown = false
        homeButton.AutoButtonColor = true
        homeButton.BackgroundTransparency = 0
    end)
end)

print("[SpawnController] Loaded")
