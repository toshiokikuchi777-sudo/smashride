-- EventService.lua
-- イベント進行管理(カウントダウン、開始終了、ChestServiceとの連携)

local EventService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local ChestConfig = require(ReplicatedStorage.Shared.Config.ChestConfig)

-- イベント状態
local eventState = {
	currentEventId = "RAINBOW_BONUS",
	nextEventId = "RAINBOW_BONUS", -- 次に発生するイベント
	isActive = false,
	startTime = 0,
	endTime = 0,
	lastEventEndTime = 0
}

-- Remote定義
Net.E(Constants.Events.EventStateSync) -- サーバー → 全員(イベント状態同期)

-- 初期化
-- 初期化
function EventService.Init()
	print("[EventService] 初期化完了")
	
	-- プレイヤー参加時の同期
	Players.PlayerAdded:Connect(function(player)
		task.wait(1) -- クライアント側のロード待ち
		EventService.SyncStateToPlayer(player, EventService.GetCurrentState())
	end)
	
	-- イベントループを開始 (交互に発生させる)
	EventService.StartMainLoop()
end

-- メインループ
function EventService.StartMainLoop()
	local eventQueue = {"RAINBOW_BONUS", "FACE_TARGET_BONUS", "PIGGY_BANK_BONUS"}
	local currentIdx = 1
	
	eventState.lastEventEndTime = os.time()
	
	task.spawn(function()
		while true do
			local eventId = eventQueue[currentIdx]
			local event = EventConfig.Events[eventId]
			
			-- 次のイベントを予約（UI同期用）
			eventState.nextEventId = eventId
			
			-- 次のイベントまで待機
			local timeUntil = EventConfig.GetTimeUntilNextEvent(eventId, eventState.lastEventEndTime)
			
			local waitingStart = os.time()
			while os.time() - waitingStart < timeUntil do
				local remaining = math.max(0, timeUntil - (os.time() - waitingStart))
				EventService.SyncState({
					eventId = eventId,
					isActive = false,
					timeUntilNext = remaining
				})
				task.wait(1)
			end
			
			-- イベント開始
			EventService.StartEvent(eventId)
			
			-- イベント終了まで待機
			task.wait(event.duration)
			
			-- イベント終了
			EventService.EndEvent(eventId)
			
			-- 次のイベントへ
			currentIdx = (currentIdx % #eventQueue) + 1
		end
	end)
end

-- イベント開始
function EventService.StartEvent(eventId)
	local event = EventConfig.Events[eventId]
	if not event then return end
	
	eventState.currentEventId = eventId
	eventState.isActive = true
	eventState.startTime = os.time()
	eventState.endTime = eventState.startTime + event.duration
	
	print("[EventService] イベント開始:", eventId)
	
	-- スポーン処理
	if eventId == "RAINBOW_BONUS" then
		EventService.RunRainbowChestSpawn(event)
	elseif eventId == "FACE_TARGET_BONUS" then
		EventService.RunFaceTargetSpawn(event)
	elseif eventId == "PIGGY_BANK_BONUS" then
		EventService.RunPiggyBankSpawn(event)
	end
	
	-- 状態同期ループ(1秒ごと)
	task.spawn(function()
		while eventState.isActive and eventState.currentEventId == eventId do
			local remaining = EventConfig.GetEventRemainingTime(eventId, eventState.startTime)
			EventService.SyncState({
				eventId = eventId,
				isActive = true,
				remainingTime = remaining
			})
			task.wait(1)
		end
	end)
end

-- 宝箱スポーンロジック
function EventService.RunRainbowChestSpawn(event)
	local ChestService = require(script.Parent.ChestService)
	task.spawn(function()
		while eventState.isActive and eventState.currentEventId == "RAINBOW_BONUS" do
			if math.random() < event.spawnMode.spawnChance then
				local targetPos = EventService.GetSpawnPosition("Chests", 60)
				if targetPos then
					ChestService.SpawnChest(ChestConfig.SelectRandomChestType(), targetPos)
				end
			end
			task.wait(event.spawnMode.spawnEverySeconds)
		end
	end)
end

-- 顔ターゲットスポーンロジック
function EventService.RunFaceTargetSpawn(event)
	local FaceTargetService = require(script.Parent.FaceTargetService)
	
	-- フォルダを取得
	local spawnPointsFolder = workspace:FindFirstChild("MapSettings") 
		and workspace.MapSettings:FindFirstChild("SpawnPoints")
		and workspace.MapSettings.SpawnPoints:FindFirstChild("FaceTargets")
	
	if not spawnPointsFolder then
		warn("[EventService] FaceTargets スポーン用フォルダが見つかりません。")
		return
	end
	
	local points = spawnPointsFolder:GetChildren()
	print(string.format("[EventService] %d 個の地点に顔を出現させます", #points))
	
	for _, p in ipairs(points) do
		if p:IsA("BasePart") then
			-- 名称に基づいてタイプを決定 (RARE または NORMAL)
			local targetType = "NORMAL"
			if string.find(string.upper(p.Name), "RARE") then
				targetType = "RARE"
			end
			
			-- 各パーツの位置に出現させる (パーツ本体を渡して天面を計算させる)
			FaceTargetService.SpawnFaceTarget(targetType, p.Position, p)
		end
	end
end

-- 豚の貯金箱スポーンロジック
function EventService.RunPiggyBankSpawn(event)
	local PiggyBankService = require(script.Parent.PiggyBankService)
	
	-- フォルダを取得 (顔と同じ地点を使用)
	local spawnPointsFolder = workspace:FindFirstChild("MapSettings") 
		and workspace.MapSettings:FindFirstChild("SpawnPoints")
		and workspace.MapSettings.SpawnPoints:FindFirstChild("FaceTargets")
	
	if not spawnPointsFolder then
		warn("[EventService] PiggyBank スポーン用フォルダが見つかりません。")
		return
	end
	
	local points = spawnPointsFolder:GetChildren()
	print(string.format("[EventService] %d 個の地点に豚の貯金箱を出現させます", #points))
	
	for _, p in ipairs(points) do
		if p:IsA("BasePart") then
			-- PIGGY として出現させる
			PiggyBankService.SpawnPiggy("PIGGY", p.Position, p)
		end
	end
end

-- 座標取得ロジック（カスタムポイント優先、なければプレイヤー付近）
function EventService.GetSpawnPosition(category, playerNearRadius, optionalName)
	-- 1. カスタムスポーンポイントの確認
	local spawnPointsFolder = workspace:FindFirstChild("MapSettings") 
		and workspace.MapSettings:FindFirstChild("SpawnPoints")
		and workspace.MapSettings.SpawnPoints:FindFirstChild(category)
	
	if spawnPointsFolder then
		local points = spawnPointsFolder:GetChildren()
		local validPoints = {}
		local priorityPoints = {}
		
		for _, p in ipairs(points) do
			if p:IsA("BasePart") then 
				table.insert(validPoints, p)
				-- 名前に指定の文字列が含まれていれば優先リストへ (例: RARE)
				if optionalName and string.find(string.upper(p.Name), string.upper(optionalName)) then
					table.insert(priorityPoints, p)
				end
			end
		end
		
		-- 優先リストがあればそこから、なければ全体から選ぶ
		local pool = (#priorityPoints > 0) and priorityPoints or validPoints
		if #pool > 0 then
			local targetPart = pool[math.random(1, #pool)]
			print(string.format("[EventService] カスタム地点を使用 (%s%s): %s", 
				category, (optionalName and (" - "..optionalName) or ""), targetPart.Name))
			-- パーツの位置をそのまま返す (FaceTargetService側で地面判定を行う)
			return targetPart.Position
		end
	end
	
	-- 2. プレイヤー付近（フォールバック）
	return EventService.GetRandomPlayerNearPosition(playerNearRadius)
end

-- 共通: プレイヤーの近くの座標を取得
function EventService.GetRandomPlayerNearPosition(radius)
	local allPlayers = Players:GetPlayers()
	if #allPlayers == 0 then return nil end
	
	local luckyPlayer = allPlayers[math.random(1, #allPlayers)]
	if luckyPlayer.Character and luckyPlayer.Character:FindFirstChild("HumanoidRootPart") then
		return ChestConfig.GetSpawnPositionNear(luckyPlayer.Character.HumanoidRootPart.Position, radius)
	end
	return nil
end

-- イベント終了
function EventService.EndEvent(eventId)
	if eventState.currentEventId ~= eventId then return end
	
	eventState.isActive = false
	eventState.lastEventEndTime = os.time()
	
	if eventId == "RAINBOW_BONUS" then
		require(script.Parent.ChestService).ClearAllChests()
	elseif eventId == "FACE_TARGET_BONUS" then
		require(script.Parent.FaceTargetService).ClearAllTargets()
	elseif eventId == "PIGGY_BANK_BONUS" then
		require(script.Parent.PiggyBankService).ClearAllTargets()
	end
	
	print("[EventService] イベント終了:", eventId)
end

-- 状態を全員に同期
function EventService.SyncState(state)
	Net.Fire(Constants.Events.EventStateSync, state)
end

-- 特定のプレイヤーにのみ同期
function EventService.SyncStateToPlayer(player, state)
	local remote = Net.E(Constants.Events.EventStateSync)
	remote:FireClient(player, state)
end

-- 現在の状態を取得
function EventService.GetCurrentState()
	if eventState.isActive then
		local remaining = EventConfig.GetEventRemainingTime(eventState.currentEventId, eventState.startTime)
		return {
			eventId = eventState.currentEventId,
			isActive = true,
			remainingTime = remaining
		}
	else
		local nextId = eventState.nextEventId or "RAINBOW_BONUS"
		local timeUntil = EventConfig.GetTimeUntilNextEvent(nextId, eventState.lastEventEndTime)
		return {
			eventId = nextId,
			isActive = false,
			timeUntilNext = timeUntil
		}
	end
end

return EventService
