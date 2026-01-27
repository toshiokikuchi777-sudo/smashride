-- StarterPlayerScripts/ClientMain.lua
print("!!! [ClientMain] SCRIPT STARTING !!!")

local UIS = game:GetService("UserInputService")
task.defer(function()
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    print("[ClientMain] Mouse setup finished.")
end)

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

print("[ClientMain] Player recognized:", player.Name)

local Controllers = script.Parent:WaitForChild("Controllers")
print("[ClientMain] Controllers folder found.")

-- Async initialization helper
local function safeInit(name)
	task.spawn(function()
		print("[ClientMain] ---> Loading " .. name .. "...")
		local ok, module = pcall(function()
			return require(Controllers:WaitForChild(name .. "Controller", 10))
		end)
		
		if not ok or not module then
			warn("[ClientMain] [FAIL] Could not load " .. name .. ": " .. tostring(module))
			return
		end
		
		print("[ClientMain] [OK] " .. name .. " Loaded. Initializing...")
		if module.Init then
			module.Init()
			print("[ClientMain] [DONE] " .. name .. " Initialized.")
		else
			warn("[ClientMain] [MISSING] " .. name .. " has no Init function.")
		end
	end)
end

-- Load all controllers independently
safeInit("Can")
safeInit("Pet")
safeInit("Gacha")
safeInit("Inventory")
safeInit("PetInventory")  -- ペット専用UI
safeInit("Leaderboard")
safeInit("Stage")
safeInit("BGM")
safeInit("Skateboard")
safeInit("SkateboardShop")
safeInit("HammerShop")
safeInit("GachaInteraction")
safeInit("Survey")
safeInit("Chest")
safeInit("Promotion")

-- ChestEventUIの初期化(Controllerではないため直接require)
task.spawn(function()
	print("[ClientMain] ---> Loading ChestEventUI...")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	
	-- タイムアウト付きでWaitForChild
	local Client = ReplicatedStorage:WaitForChild("Client", 5)
	if not Client then
		warn("[ClientMain] [SKIP] Client folder not found, skipping ChestEventUI")
		return
	end
	
	local UI = Client:WaitForChild("UI", 5)
	if not UI then
		warn("[ClientMain] [SKIP] UI folder not found, skipping ChestEventUI")
		return
	end
	
	local ChestEventUIModule = UI:WaitForChild("ChestEventUI", 5)
	if not ChestEventUIModule then
		warn("[ClientMain] [SKIP] ChestEventUI not found, skipping")
		return
	end
	
	local ok, ChestEventUI = pcall(function()
		return require(ChestEventUIModule)
	end)
	
	if ok and ChestEventUI and ChestEventUI.Init then
		ChestEventUI.Init()
		print("[ClientMain] [DONE] ChestEventUI Initialized.")
	else
		warn("[ClientMain] [FAIL] Could not load ChestEventUI:", tostring(ChestEventUI))
	end
end)

print("!!! [ClientMain] ASYNC BOOTSTRAP STARTED !!!")
