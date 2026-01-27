-- ServerScriptService/Services/LeaderboardService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local DataStoreService = game:GetService("DataStoreService")
local LB_VERSION = GameConfig.LEADERBOARD_VERSION or "V1"
local scrapBoard = DataStoreService:GetOrderedDataStore("Leaderboard_Scrap_" .. LB_VERSION)
local smashedBoard = DataStoreService:GetOrderedDataStore("Leaderboard_Smashed_" .. LB_VERSION)

-- Name cache to avoid hitting Players:GetNameFromUserIdAsync too hard
local nameCache = {}

local LeaderboardService = {}

-- Cache for leaderboard data
local cachedData = {
	rev = 0,
	boards = {
		SCRAP = {},
		SMASHED = {}
	}
}

-- Resolve UserId to Name with local cache
local function getName(userId)
	userId = tonumber(userId)
	if not userId then return "Unknown" end
	
	if nameCache[userId] then return nameCache[userId] end
	
	-- Try to get from online players first
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.Name
	end
	
	-- Fallback to API
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	
	if ok then
		nameCache[userId] = name
		return name
	end
	
	return "User_" .. userId
end

local function getTopEntries(orderedStore, keyName)
	local entries = {}
	local ok, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, 50) -- Top 50, descending
	end)
	
	if ok then
		local page = pages:GetCurrentPage()
		for i, data in ipairs(page) do
			table.insert(entries, {
				rank = i,
				userId = data.key,
				name = getName(data.key),
				value = data.value
			})
		end
	else
		warn("[LeaderboardService] Failed to fetch global " .. keyName .. ":", pages)
	end
	
	return entries
end

-- Update cached leaderboard data from OrderedDataStore
local function updateLeaderboards()
	cachedData.rev = cachedData.rev + 1
	
	local scrapData = getTopEntries(scrapBoard, "SCRAP")
	local smashedData = getTopEntries(smashedBoard, "SMASHED")
	
	cachedData.boards.SCRAP = scrapData
	cachedData.boards.SMASHED = smashedData
	
	print("[LeaderboardService] Updated GLOBAL leaderboards, rev:", cachedData.rev)
end

-- Handle RequestLeaderboard
local function onRequestLeaderboard(player, tab)
	print("[LeaderboardService] RequestLeaderboard from:", player.Name, "tab:", tab)
	
	-- Update data before sending
	updateLeaderboards()
	
	-- Return full payload
	return cachedData
end

-- Periodic update and broadcast
local function startPeriodicUpdate()
	task.spawn(function()
		while true do
			task.wait(20) -- Update every 20 seconds
			
			updateLeaderboards()
			
			-- Broadcast to all clients
			local LeaderboardSync = Net.E(Constants.Events.LeaderboardSync)
			LeaderboardSync:FireAllClients(cachedData)
			
			print("[LeaderboardService] Broadcasted update to all clients")
		end
	end)
end

function LeaderboardService.Init()
	print("[LeaderboardService] Init")
	
	-- Register RemoteFunction
	local RequestLeaderboard = Net.F(Constants.Functions.RequestLeaderboard)
	RequestLeaderboard.OnServerInvoke = onRequestLeaderboard
	
	-- Pre-create broadcast event
	Net.E(Constants.Events.LeaderboardSync)
	
	-- Initial update
	updateLeaderboards()
	
	-- Start periodic updates
	startPeriodicUpdate()
	
	print("[LeaderboardService] Init complete")
end

return LeaderboardService
