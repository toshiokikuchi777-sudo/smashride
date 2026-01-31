-- StarterPlayerScripts/ClientMain.lua
print("!!! [ClientMain] SCRIPT STARTING !!!")
local UIS = game:GetService("UserInputService")
task.defer(function()
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    print("[ClientMain] Mouse setup finished.")
end)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
print("[ClientMain] Player recognized:", player.Name)
local Controllers = script.Parent:WaitForChild("Controllers")

local function safeInit(name)
	task.spawn(function()
		print("[ClientMain] ---> Loading " .. name .. "...")
		local ok, module = pcall(function() return require(Controllers:WaitForChild(name .. "Controller", 10)) end)
		if not ok or not module then warn("[ClientMain] [FAIL] " .. name .. ": " .. tostring(module)); return end
		print("[ClientMain] [OK] " .. name .. " Loaded. Initializing...")
		if module.Init then module.Init(); print("[ClientMain] [DONE] " .. name .. " Initialized.")
		else warn("[ClientMain] [MISSING] " .. name .. " Init") end
	end)
end

safeInit("Can")
safeInit("Pet")
safeInit("Gacha")
safeInit("Inventory")
safeInit("PetInventory")
safeInit("Leaderboard")
safeInit("Stage")
safeInit("BGM")
safeInit("Skateboard")
safeInit("Grind")
safeInit("SkateboardShop")
safeInit("HammerShop")
safeInit("GachaInteraction")
safeInit("Survey")
safeInit("Chest")
safeInit("Promotion")
safeInit("Event")

task.spawn(function()
	print("[ClientMain] ---> Loading ChestEventUI...")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local UI = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI")
	local ChestEventUI = require(UI:WaitForChild("ChestEventUI"))
	ChestEventUI.Init()
	print("[ClientMain] [DONE] ChestEventUI Initialized.")
end)
print("!!! [ClientMain] ASYNC BOOTSTRAP STARTED !!!")
