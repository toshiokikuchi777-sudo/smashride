local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SubmitSurvey = ReplicatedStorage:WaitForChild("SubmitSurvey")

-- 設定
local GAS_URL = "https://script.google.com/macros/s/AKfycbyIV_caA6PwHpwP15KD_b_LeJqEbnpo3pkwygimmrE6eXOJBDBaChZSenheIq60VSI8/exec"
local SECRET = "SMASHRIDE" -- 提供されたGAS側のSECRETと一致させる

local SurveyService = {}

local function onSurveySubmitted(player, answers)
	if not answers then return end
	
	-- セッションID生成
	local sessionId = HttpService:GenerateGUID(false)
	
	local payload = {
		secret = SECRET,
		placeId = game.PlaceId,
		userId = player.UserId,
		sessionId = sessionId,
		answers = {
			fun = tonumber(answers.fun) or 0,
			difficulty = tostring(answers.difficulty) or "Unknown",
			replay = tostring(answers.replay) or "Unknown",
			comment = tostring(answers.comment) or ""
		}
	}
	
	local success, result = pcall(function()
		local json = HttpService:JSONEncode(payload)
		return HttpService:PostAsync(GAS_URL, json, Enum.HttpContentType.ApplicationJson)
	end)
	
	if success then
		print("Survey submitted successfully for player: " .. player.Name)
	else
		warn("!! SURVEY SUBMIT FAILED !!")
		warn("Player: " .. player.Name)
		warn("Error Message: " .. tostring(result))
		warn("Target URL: " .. GAS_URL)
		warn("Check if GAS Deployment is set to 'Anyone' and has 'doPost' function.")
	end
end

function SurveyService.Init()
	print("[SurveyService] Initializing...")
	SubmitSurvey.OnServerEvent:Connect(onSurveySubmitted)
end

return SurveyService
