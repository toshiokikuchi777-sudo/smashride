--// ServerScriptService/Services/PromotionService.lua

local PromotionService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(ServerScriptService.Services.DataService)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)
local PromotionConfig = require(ReplicatedStorage.Shared.Config.PromotionConfig)
local HammerShopService = require(ServerScriptService.Services.HammerShopService)
local CanService = require(ServerScriptService.Services.CanService)

-- テスト設定
local TEST_MODE = false -- 本番運用のためfalseに設定。Studioでテストする場合はtrueに。

-- RemoteEvents
Net.E(Constants.Events.ClaimFeedbackReward) -- クライアントからのリクエスト
Net.E(Constants.Events.RewardNotification)  -- クライアントへの通知

function PromotionService.Init()
	-- フィードバック報酬のリクエスト受信
	Net.On(Constants.Events.ClaimFeedbackReward, function(player)
		PromotionService.ClaimFeedback(player)
	end)

	-- プレイヤー参加時にグループ報酬をチェック
	Players.PlayerAdded:Connect(function(player)
		task.wait(5) -- データロード待ち
		PromotionService.CheckCommunityReward(player)
	end)

	-- 起動時に既にいるプレイヤーもチェック
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			task.wait(5)
			PromotionService.CheckCommunityReward(player)
		end)
	end

	print("[PromotionService] Init complete")
end

-- フィードバック報酬の付与
function PromotionService.ClaimFeedback(player)
	local data = DataService.Get(player)
	if not data or data.hasClaimedFeedback then return end

	-- 報酬付与
	data.hasClaimedFeedback = true
	player:SetAttribute("HasClaimedFeedback", true)
	DataService.MarkDirty(player)

	local amount = PromotionConfig.FeedbackReward.Amount
	CanService.AddScore(player, amount)
	
	-- 通知 (必要なら)
	Net.Fire(Constants.Events.RewardNotification, {
		type = "FEEDBACK",
		message = "👍 THANKS! コインを獲得しました！",
		amount = amount
	}, player)

	print(string.format("[PromotionService] %s claimed feedback reward", player.Name))
end

-- コミュニティ報酬のチェックと付与
function PromotionService.CheckCommunityReward(player)
	local data = DataService.Get(player)
	if not data then return end

	-- フィードバック状態の同期(Attribute)
	player:SetAttribute("HasClaimedFeedback", data.hasClaimedFeedback == true)

	if data.claimedRainbowHammer then return end

	local groupId = PromotionConfig.CommunityReward.GroupId
	if groupId == 0 then return end -- ID未設定時はスキップ

	local isMember = false
	
	-- TEST_MODE: Studioでのテスト用に自動付与
	if TEST_MODE then
		print("[PromotionService] TEST_MODE: Auto-granting Rainbow Hammer to", player.Name)
		isMember = true
	else
		-- 本番: グループメンバーシップをチェック
		local ok, result = pcall(function()
			return player:IsInGroup(groupId)
		end)
		isMember = ok and result
	end
	
	if isMember then
		-- ハンマー付与
		data.claimedRainbowHammer = true
		
		-- 既に持っていないか確認して追加
		local hasHammer = false
		local hammerId = PromotionConfig.CommunityReward.HammerId
		for _, h in ipairs(data.ownedHammers) do
			if h == hammerId then
				hasHammer = true
				break
			end
		end
		
		if not hasHammer then
			table.insert(data.ownedHammers, hammerId)
		end
		
		DataService.MarkDirty(player)
		
		-- 獲得演出などのために通知
		Net.Fire(Constants.Events.RewardNotification, {
			type = "COMMUNITY",
			message = PromotionConfig.CommunityReward.CongratsText,
			hammerId = hammerId
		}, player)
		
		print(string.format("[PromotionService] %s awarded Rainbow Hammer (%s)", player.Name, tostring(hammerId)))
	end
end

return PromotionService
