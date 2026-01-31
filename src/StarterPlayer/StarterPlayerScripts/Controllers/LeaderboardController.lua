-- StarterPlayer/StarterPlayerScripts/Controllers/LeaderboardController.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))

local LeaderboardController = {}

-- State
local gui = nil
local root = nil
local openButton = nil
local closeButton = nil
local tabScrap = nil
local tabSmashed = nil
local list = nil
local rowTemplate = nil
local currentTab = "SCRAP" -- Default tab

-- 3D Board References
local worldRoot = workspace:FindFirstChild("LeaderboardRoot")

-- Format number with commas
local function formatNumber(num)
	local formatted = tostring(num)
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

-- Clear all rows except template for a given list
local function clearRowsFromList(targetList)
	if not targetList then return end
	for _, child in ipairs(targetList:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "RowTemplate" and child.Name ~= "UIListLayout" then
			child:Destroy()
		end
	end
end

-- Render rows from data to a specific list
local function renderRowsToTarget(boardData, targetList, tabType)
	if not targetList then return end
	local template = targetList:FindFirstChild("RowTemplate")
	if not template then return end

	clearRowsFromList(targetList)
	
	if not boardData or #boardData == 0 then
		return
	end
	
	for i, entry in ipairs(boardData) do
		if i > 50 then break end -- Limit to 50
		local row = template:Clone()
		row.Name = "Row_" .. entry.rank
		row.Visible = true
		row.LayoutOrder = entry.rank
		
		-- Rank
		local rankLabel = row:FindFirstChild("Rank")
		if rankLabel then
			rankLabel.Text = "#" .. entry.rank
			if entry.rank <= 3 then
				rankLabel.Font = Enum.Font.GothamBold
				rankLabel.TextColor3 = (entry.rank == 1 and Color3.fromRGB(255, 215, 0))
						or (entry.rank == 2 and Color3.fromRGB(192, 192, 192))
						or (entry.rank == 3 and Color3.fromRGB(205, 127, 50))
						or Color3.new(1,1,1)
			end
		end
		
		-- Name
		local nameLabel = row:FindFirstChild("Name")
		if nameLabel then
			nameLabel.Text = entry.name or ("Player " .. entry.userId)
		end
		
		-- Value
		local valueLabel = row:FindFirstChild("Value")
		if valueLabel then
			if tabType == "SCRAP" then
				valueLabel.Text = formatNumber(entry.value)
			else
				valueLabel.Text = formatNumber(entry.value) .. " smashed"
			end
		end
		
		row.Parent = targetList
	end
end

-- Update all leaderboards (2D and 3D)
local function updateAllLeaderboards(payload)
	if not payload or not payload.boards then return end

	-- 1. Update ScreenGui List (only for current tab)
	if root and root.Visible and payload.boards[currentTab] then
		renderRowsToTarget(payload.boards[currentTab], list, currentTab)
	end

	-- 2. Update 3D Boards in Workspace
	if not worldRoot then worldRoot = workspace:FindFirstChild("LeaderboardRoot") end
	if worldRoot then
		-- Scrap Board
		local scrapBoard = worldRoot:FindFirstChild("Board_Scrap")
		if scrapBoard then
			local sGui = scrapBoard:FindFirstChild("SurfaceGui")
			local sList = sGui and sGui:FindFirstChild("List", true)
			if sList then
				renderRowsToTarget(payload.boards.SCRAP, sList, "SCRAP")
			end
		end

		-- Smashed Board
		local smashedBoard = worldRoot:FindFirstChild("Board_Smashed")
		if smashedBoard then
			local sGui = smashedBoard:FindFirstChild("SurfaceGui")
			local sList = sGui and sGui:FindFirstChild("List", true)
			if sList then
				renderRowsToTarget(payload.boards.SMASHED, sList, "SMASHED")
			end
		end
	end
end

-- Switch tab (For 2D GUI)
local function switchTab(tab)
	currentTab = tab
	
	-- Update tab appearance
	if tabScrap and tabSmashed then
		if tab == "SCRAP" then
			tabScrap.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			tabScrap.TextColor3 = Color3.fromRGB(255, 255, 255)
			tabSmashed.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			tabSmashed.TextColor3 = Color3.fromRGB(180, 180, 180)
		else
			tabScrap.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			tabScrap.TextColor3 = Color3.fromRGB(180, 180, 180)
			tabSmashed.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			tabSmashed.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
	
	-- Request data for new tab for immediate feedback in 2D UI
	local RequestLeaderboard = Net.F(Constants.Functions.RequestLeaderboard)
	local success, result = pcall(function()
		return RequestLeaderboard:InvokeServer(tab)
	end)
	
	if success and result then
		updateAllLeaderboards(result)
	end
end

-- Open panel
local function openPanel()
	if not root then return end
	root.Visible = true
	if openButton then openButton.Visible = false end
	switchTab(currentTab) -- Load data
end

-- Close panel
local function closePanel()
	if not root then return end
	root.Visible = false
	if openButton then openButton.Visible = true end
end

-- Handle LeaderboardSync event
local function onLeaderboardSync(payload)
	if not payload or not payload.boards then return end
	print("[LeaderboardController] Sync received, rev:", payload.rev)
	updateAllLeaderboards(payload)
end

function LeaderboardController.Init()
	print("[LeaderboardController] Init")
	
	-- 1. Setup 2D ScreenGui if exists
	gui = playerGui:FindFirstChild("LeaderboardGui")
	if gui then
		root = gui:FindFirstChild("Root")
		if root then
			local mainHud = playerGui:FindFirstChild("MainHud")
			openButton = (mainHud and mainHud:FindFirstChild("OpenButton", true)) or gui:FindFirstChild("OpenButton", true)
			
			local header = root:FindFirstChild("Header")
			if header then
				closeButton = header:FindFirstChild("Close")
			end
			
			local tabs = root:FindFirstChild("Tabs")
			if tabs then
				tabScrap = tabs:FindFirstChild("TabScrap")
				tabSmashed = tabs:FindFirstChild("TabSmashed")
			end
			
			list = root:FindFirstChild("List")
			rowTemplate = list and list:FindFirstChild("RowTemplate")
			
			-- Bind 2D UI events
			if openButton then openButton.Activated:Connect(openPanel) end
			if closeButton then closeButton.Activated:Connect(closePanel) end
			if tabScrap then tabScrap.Activated:Connect(function() switchTab("SCRAP") end) end
			if tabSmashed then tabSmashed.Activated:Connect(function() switchTab("SMASHED") end) end
		end
	end
	
	-- 2. Initial Data fetch for all boards
	task.spawn(function()
		-- Wait for RemoteFunction to be created
		local maxWait = 10
		local waited = 0
		local RequestLeaderboard = nil
		
		while waited < maxWait do
			local success, remote = pcall(function()
				return Net.F(Constants.Functions.RequestLeaderboard)
			end)
			
			if success and remote then
				RequestLeaderboard = remote
				break
			end
			
			task.wait(0.5)
			waited = waited + 0.5
		end
		
		if not RequestLeaderboard then
			return
		end
		
		-- Fetch initial data
		local success, result = pcall(function()
			return RequestLeaderboard:InvokeServer("SCRAP") -- Get all data
		end)
		
		if success and result then
			updateAllLeaderboards(result)
		end
	end)

	-- 3. Listen for sync events
	local syncEvent = Net.E(Constants.Events.LeaderboardSync)
	syncEvent.OnClientEvent:Connect(onLeaderboardSync)
end

return LeaderboardController
