local Workspace     = game:GetService("Workspace")
local TweenService   = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")

local SpawnerService = {}

local function getTemplates()
	return ServerStorage:FindFirstChild("Templates")
end

local function getCansTemplates()
	local t = getTemplates()
	return t and t:FindFirstChild("Cans")
end

-- 指定した Spawner の位置に缶を 1 個出す
function SpawnerService.SpawnAtSpawner(spawnerPart, firstDelay)
	-- 即座に出す（delayが必要な場合は呼び出し側で管理）
	local cansTemplates = getCansTemplates()
	if not cansTemplates then
		warn("[SpawnerService] cansTemplates NOT FOUND")
		return
	end

	-- テンプレートフォルダ内の缶から選ぶ
	local availableCans = cansTemplates:GetChildren()
	if #availableCans == 0 then 
		warn("[SpawnerService] No can templates found in ServerStorage/Templates/Cans")
		return 
	end

	local forcedColor = spawnerPart:GetAttribute("CanColor")
	local targetTemplate = nil

	if forcedColor then
		targetTemplate = cansTemplates:FindFirstChild(forcedColor)
	end

	if not targetTemplate then
		targetTemplate = availableCans[math.random(1, #availableCans)]
	end

	local newCan = targetTemplate:Clone()
	newCan.Name = forcedColor or targetTemplate.Name
	
	local primary = newCan.PrimaryPart or newCan:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		local randomX = math.random(-120, 120) / 10 -- +/- 12 studs
		local randomZ = math.random(-120, 120) / 10 
		
		local targetPos = spawnerPart.Position + Vector3.new(randomX, 0, randomZ)
		-- 地面に設置 (1/3倒す = 約30度傾ける)
		local rotation = CFrame.Angles(0, math.rad(math.random(0,360)), 0) * CFrame.Angles(math.rad(30), 0, 0)
		newCan:PivotTo(CFrame.new(targetPos.X, 0, targetPos.Z) * rotation)
		
		-- Anchored 徹底
		for _, p in ipairs(newCan:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
		
		local cansFolder = Workspace:FindFirstChild("Cans")
		if not cansFolder then
			cansFolder = Instance.new("Folder", Workspace)
			cansFolder.Name = "Cans"
		end
		newCan.Parent = cansFolder
		
		-- print(string.format("[SpawnerService] Placed %s at Z=%.1f", newCan.Name, targetPos.Z))
	end

	-- どのスポナーから生まれたか覚えさせる
	local spawnRef = Instance.new("ObjectValue")
	spawnRef.Name  = "SpawnPoint"
	spawnRef.Value = spawnerPart
	spawnRef.Parent = newCan
end

-- ゲーム開始時：全スポナーから 1 個ずつ缶を出す
function SpawnerService.Init()
	local spawnerFolder = Workspace:FindFirstChild("CanSpawners")
	if not spawnerFolder then
		warn("[SpawnerService] Cannot start Init: spawnerFolder (CanSpawners) is missing in Workspace!")
		return
	end
	local spawners = spawnerFolder:GetChildren()
	for _, spawner in ipairs(spawners) do
		if spawner:IsA("BasePart") then
			SpawnerService.SpawnAtSpawner(spawner, 0)
		end
	end
end

return SpawnerService
