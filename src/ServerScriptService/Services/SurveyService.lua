local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SubmitSurvey = ReplicatedStorage:WaitForChild("SubmitSurvey")

-- 設定
local SURVEY_ENABLED = false -- Survey機能を無効化(GAS設定が完了したらtrueに変更)
local GAS_URL = "https://script.google.com/macros/s/AKfycbyIV_caA6PwHpwP15KD_b_LeJqEbnpo3pkwygimmrE6eXOJBDBaChZSenheIq60VSI8/exec"
local SECRET = "SMASHRIDE" -- 提供されたGAS側のSECRETと一致させる

local SurveyService = {}

local function onSurveySubmitted(player, answers)
	if not answers then return end
	
	-- Survey機能が無効の場合はスキップ
	if not SURVEY_ENABLED then
		print("[SurveyService] Survey disabled. Skipping submission for:", player.Name)
		return
	end
	
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
		print("[SurveyService] ✅ Survey submitted:", player.Name)
	else
		-- エラーを1行で簡潔に表示
		warn(string.format("[SurveyService] ❌ Survey failed for %s: %s (GAS設定を確認してください)", player.Name, tostring(result)))
	end
end

function SurveyService.Init()
	if SURVEY_ENABLED then
		print("[SurveyService] ✅ Survey enabled and ready")
	else
		print("[SurveyService] ⚠️ Survey disabled (SURVEY_ENABLED = false)")
	end
	SubmitSurvey.OnServerEvent:Connect(onSurveySubmitted)
end

return SurveyService
