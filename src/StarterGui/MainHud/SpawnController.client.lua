-- StarterGui/MainHud/SpawnController.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local RE_RequestSpawn = Net.E("RequestSpawn")

local gui = script.Parent
local homeButton = gui:WaitForChild("HomeButton", 10)

if not homeButton then
    warn("[SpawnController] HomeButton not found in HUD")
    return
end

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
