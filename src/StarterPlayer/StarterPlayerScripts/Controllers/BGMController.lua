-- StarterPlayer/StarterPlayerScripts/Controllers/BGMController.lua
print("[BGMController] Module Loading...")
local BGMController = {}
local SoundService = game:GetService("SoundService")

-- Guaranteed Audio ID (The Great Strategy - Classic Roblox Music)
local BGM_ID = "rbxassetid://142376088"
local VOLUME = 0.05  -- BGM音量をさらに下げる

function BGMController.Init()
	print("[BGMController] Init starting...")

	local bgm = SoundService:FindFirstChild("MainBGM")
	if not bgm then
		print("[BGMController] MainBGM object missing in SoundService, creating locally.")
		bgm = Instance.new("Sound")
		bgm.Name = "MainBGM"
		bgm.SoundId = BGM_ID
		bgm.Looped = true
		bgm.Parent = SoundService
	end

	-- 既存・新規に関わらず最新の音量を適用
	bgm.Volume = VOLUME

	task.spawn(function()
		print("[BGMController] Monitoring playback...")
		while true do
			if not bgm.IsPlaying then
				bgm:Play()
				print("[BGMController] Play() command sent.")
			end

			if bgm.TimePosition > 0 then
				print("[BGMController] BGM confirmed playing! Time:", bgm.TimePosition)
				break
			end
			task.wait(2)
		end
	end)
end

return BGMController
