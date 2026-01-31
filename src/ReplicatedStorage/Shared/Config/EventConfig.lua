-- ReplicatedStorage/Shared/Config/EventConfig.lua
-- ボーナスイベントの設定

local EventConfig = {}

EventConfig.Events = {
	RAINBOW_BONUS = {
		id = "RAINBOW_BONUS",
		displayName = "レインボー・ボーナス!",
		duration = 45, -- 秒 (デモ用に短縮)
		interval = 10, -- 秒 (デモ用に短縮)
		
		spawnMode = {
			spawnEverySeconds = 0.5,
			spawnChance = 1.0
		},
		
		chestPool = {
			RED = 60,
			BLUE = 25,
			GREEN = 12,
			GOLD = 3
		},
		
		worldEffect = "RAINBOW_FILTER",
		ui = {
			title = "RAINBOW BONUS TIME!",
			subtitle = "宝箱が降ってくる!",
			color = Color3.fromRGB(255, 100, 255)
		}
	},
	
	FACE_TARGET_BONUS = {
		id = "FACE_TARGET_BONUS",
		displayName = "フェイスパニック!",
		duration = 45,
		interval = 10,
		
		spawnMode = {
			spawnEverySeconds = 3,
			spawnChance = 0.8
		},
		
		ui = {
			title = "FACE TARGET BONUS!",
			subtitle = "巨大な顔を叩いてコインをゲット!",
			color = Color3.fromRGB(255, 200, 100)
		}
	},
	
	PIGGY_BANK_BONUS = {
		id = "PIGGY_BANK_BONUS",
		displayName = "ポーク・フィーバー!",
		duration = 45,
		interval = 10,
		
		spawnMode = {
			spawnEverySeconds = 2,
			spawnChance = 0.9
		},
		
		ui = {
			title = "PIGGY BANK BONUS!",
			subtitle = "豚の貯金箱を叩いて大量コインをゲット!",
			color = Color3.fromRGB(255, 150, 150)
		}
	}
}

-- 次のイベントまでの時間を計算(秒)
function EventConfig.GetTimeUntilNextEvent(eventId, lastEventEndTime)
	local event = EventConfig.Events[eventId]
	if not event then return 0 end
	
	local currentTime = os.time()
	local nextEventTime = lastEventEndTime + event.interval
	local timeUntil = nextEventTime - currentTime
	
	return math.max(0, timeUntil)
end

-- イベントの残り時間を計算(秒)
function EventConfig.GetEventRemainingTime(eventId, eventStartTime)
	local event = EventConfig.Events[eventId]
	if not event then return 0 end
	
	local currentTime = os.time()
	local elapsed = currentTime - eventStartTime
	local remaining = event.duration - elapsed
	
	return math.max(0, remaining)
end

return EventConfig
