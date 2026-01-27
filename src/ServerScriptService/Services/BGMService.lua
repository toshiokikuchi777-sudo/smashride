-- ServerScriptService/Services/BGMService.lua
local SoundService = game:GetService("SoundService")
local BGMService = {}

local BGM_ID = "rbxassetid://142376088"

function BGMService.Init()
	print("[BGMService] Init starting...")
	local bgm = SoundService:FindFirstChild("MainBGM")
	if not bgm then
		bgm = Instance.new("Sound", SoundService)
		bgm.Name = "MainBGM"
	end
	
	bgm.SoundId = BGM_ID
	bgm.Looped = true
	bgm.Volume = 0.5
	bgm:Play()
	print("[BGMService] Server-side BGM started.")
end

return BGMService
