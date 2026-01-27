--// ServerScriptService/Services/DataService.lua
--// DataStore: score / pets owned / equipped (3 slots)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerSchema = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Schema"):WaitForChild("PlayerSchema"))
local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PetConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local DATA_VERSION = GameConfig.TEST_RESET_KEY or "V1"
local LB_VERSION = GameConfig.LEADERBOARD_VERSION or "V1"
local STORE_NAME = "CAN_SMASHER_" .. DATA_VERSION
local AUTOSAVE_INTERVAL = 60

local store = DataStoreService:GetDataStore(STORE_NAME)
local scrapBoard = DataStoreService:GetOrderedDataStore("Leaderboard_Scrap_" .. LB_VERSION)
local smashedBoard = DataStoreService:GetOrderedDataStore("Leaderboard_Smashed_" .. LB_VERSION)

local DataService = {}

local cache = {}      -- [player] = data
local dirty = {}      -- [player] = true/false
local loading = {}    -- [player] = true/false

local function defaultData()
	return PlayerSchema.Default()
end

local function keyFor(player)
	return "u_" .. tostring(player.UserId)
end

function DataService.Init()
	-- autosave loop
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				if dirty[player] then
					DataService.Save(player, "autosave")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.Cleanup(player)
	end)

	print("[DataService] Init complete")
end

function DataService.Load(player)
	if not player then return defaultData() end
	if loading[player] then
		-- already loading, wait until cache exists
		while loading[player] do
			task.wait()
		end
		return cache[player] or defaultData()
	end

	loading[player] = true

	local data, report
	local ok, result = pcall(function()
		return store:GetAsync(keyFor(player))
	end)

	if ok then
		data, report = PlayerSchema.ValidateAndFix(result, PetConfig.All, 3)
		if report.reset or next(report.fixed) ~= nil then
			print("[DataService/Schema] Fixed data for", player.Name, report.reset and "RESET" or "PATCHED", report.fixed)
		end
	else
		warn("[DataService] Load failed:", player.Name, result)
		data = defaultData()
	end

	cache[player] = data
	dirty[player] = false
	loading[player] = false

	print(string.format("[DataService] Loaded %s total=%d petsOwned=%d", player.Name, data.total, #data.ownedPets))
	return data
end

function DataService.Get(player)
	return cache[player]
end

function DataService.MarkDirty(player)
	if player then
		dirty[player] = true
	end
end

function DataService.Save(player, reason)
	if not player then return end
	local data = cache[player]
	if not data then return end

	-- normalize before save via Schema
	data._version = PlayerSchema.VERSION
	local validated, report = PlayerSchema.ValidateAndFix(data, PetConfig.All, 3)
	data = validated
	cache[player] = data

	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), data)
		
		-- Update global leaderboards
		pcall(function()
			scrapBoard:SetAsync(tostring(player.UserId), math.floor(data.total or 0))
			smashedBoard:SetAsync(tostring(player.UserId), math.floor(data.cansSmashedTotal or 0))
		end)
	end)

	if ok then
		dirty[player] = false
		print(string.format("[DataService] Saved %s (%s) total=%d", player.Name, tostring(reason), data.total))
	else
		warn("[DataService] Save failed:", player.Name, err)
	end
end

function DataService.Cleanup(player)
	-- wait if loading
	if loading[player] then
		while loading[player] do task.wait() end
	end

	-- save if dirty or exists
	if cache[player] then
		DataService.Save(player, "leaving")
	end

	cache[player] = nil
	dirty[player] = nil
	loading[player] = nil
end

return DataService
