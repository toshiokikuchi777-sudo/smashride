-- StarterPlayerScripts/Controllers/GachaInteractionController.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local GachaInteractionController = {}

local INTERACTION_DISTANCE = 6 -- Studs
local TIER_MAP = {
	egg1 = "BASIC",
	egg2 = "RARE",
	egg3 = "LEGEND"
}

local EGG_NAMES = { "egg1", "egg2", "egg3" }

local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PetConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local activeUIs = {}
local unlockedTiers = { BASIC = true }

local function getTierInfo(tier)
	local petTier = PetConfig.Tiers[tier] or PetConfig.Tiers.BASIC
	local unlockRule = GameConfig.GachaTierRules[tier] or { cansSmashedTotal = 0 }
	return {
		cost = petTier.cost,
		req = unlockRule.cansSmashedTotal or 0
	}
end

local function createGachaUI(egg, tier)
	local info = getTierInfo(tier)
	local isUnlocked = unlockedTiers[tier]
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GachaInteractionUI"
	billboard.Size = UDim2.new(0, 160, 0, 80) -- 縦幅を少し広げる
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Active = true
	billboard.ResetOnSpawn = false
	
	local button = Instance.new("TextButton")
	button.Name = "RollButton"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.TextScaled = true
	
	if isUnlocked then
		button.Text = string.format("%s\n(%s SCRAP)", tier, tostring(info.cost))
		UIStyle.ApplyFlashy(button)
		
		button.MouseButton1Click:Connect(function()
			local RequestGacha = Net.E(Constants.Events.RequestGacha)
			if RequestGacha then
				RequestGacha:FireServer(tier)
			end
		end)
	else
		button.Text = string.format("LOCKED\n(%d SMASHED)", info.req)
		button.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
		button.TextColor3 = Color3.fromRGB(150, 150, 150)
		button.AutoButtonColor = false
	end
	
	button.Parent = billboard
	billboard.Parent = player:WaitForChild("PlayerGui")
	billboard.Adornee = egg
	
	return billboard
end

function GachaInteractionController.Init()
	print("[GachaInteractionController] Init (Dynamic Config)")
	
	local UnlockStateSync = Net.E(Constants.Events.UnlockStateSync)
	if UnlockStateSync then
		UnlockStateSync.OnClientEvent:Connect(function(payload)
			if payload and payload.gachaTiers then
				unlockedTiers = payload.gachaTiers
				for name, ui in pairs(activeUIs) do
					ui:Destroy()
					activeUIs[name] = nil
				end
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end
		local rootPart = character.HumanoidRootPart
		
		for _, name in ipairs(EGG_NAMES) do
			local egg = workspace:FindFirstChild(name)
			if egg then
				local eggPosition = if egg:IsA("Model") then egg:GetPivot().Position else egg.Position
				local distance = (rootPart.Position - eggPosition).Magnitude
				if distance <= INTERACTION_DISTANCE then
					if not activeUIs[name] then
						local tier = TIER_MAP[name]
						activeUIs[name] = createGachaUI(egg, tier)
					end
				else
					if activeUIs[name] then
						activeUIs[name]:Destroy()
						activeUIs[name] = nil
					end
				end
			end
		end
	end)
end

return GachaInteractionController
