-- StarterPlayerScripts/Controllers/GachaInteractionController.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local GachaInteractionController = {}

local INTERACTION_DISTANCE = 6 -- Studs
local TIER_MAP = {
	egg1 = "BASIC",
	egg2 = "RARE",
	egg3 = "LEGEND"
}

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
	billboard.Size = UDim2.new(0, 160, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Active = true
	billboard.ResetOnSpawn = false
	
	local button = Instance.new("TextButton")
	button.Name = "RollButton"
	button.Size = UDim2.new(1, 0, 1, 0)
	
	if isUnlocked then
		button.Text = string.format("%s (%d)", tier, info.cost)
		UIStyle.ApplyFlashy(button)
		
		button.MouseButton1Click:Connect(function()
			print("[GachaInteractionController] Button clicked for tier:", tier)
			local RequestGacha = Net.E("RequestGacha")
			if RequestGacha then
				RequestGacha:FireServer(tier)
			end
		end)
	else
		button.Text = string.format("LOCKED (%d CANS)", info.req)
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
	print("[GachaInteractionController] Init")
	
	-- [FIX] 解放状態の同期
	local UnlockStateSync = Net.E("UnlockStateSync")
	if UnlockStateSync then
		UnlockStateSync.OnClientEvent:Connect(function(payload)
			if payload and payload.gachaTiers then
				unlockedTiers = payload.gachaTiers
				print("[GachaInteractionController] Updated unlockedTiers")
				-- 既存のUIをリセットして再作成を促す
				for name, ui in pairs(activeUIs) do
					ui:Destroy()
					activeUIs[name] = nil
				end
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end
		
		for _, name in ipairs(EGG_NAMES) do
			local egg = workspace:FindFirstChild(name)
			if egg then
				local eggPosition = if egg:IsA("Model") then egg:GetPivot().Position else egg.Position
				local distance = (rootPart.Position - eggPosition).Magnitude
				if distance <= INTERACTION_DISTANCE then
					if not activeUIs[name] then
						local tier = TIER_MAP[name]
						activeUIs[name] = createGachaUI(egg, tier)
						print("[GachaInteractionController] Showing UI for", name)
					end
				else
					if activeUIs[name] then
						activeUIs[name]:Destroy()
						activeUIs[name] = nil
						print("[GachaInteractionController] Hiding UI for", name)
					end
				end
			end
		end
	end)
end

return GachaInteractionController
