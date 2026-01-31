-- StarterPlayerScripts/Controllers/EventController.lua
-- サーバーからのイベント状態を受信しUIを更新する
local EventController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)
local EventUI = require(ReplicatedStorage.Client.UI.EventUI)

local lastEventId = nil
local lastActiveState = false

function EventController.Init()
	print("[EventController] 初期化開始")

	EventUI.Init()

	-- サーバーからのイベント状態同期を受信
	Net.On(Constants.Events.EventStateSync, function(state)
		if not state then return end
		
		-- UIの文字更新
		EventUI.Update(state)
		
		-- イベント開始時の演出 (非アクティブ -> アクティブ への切り替え時)
		if state.isActive and not lastActiveState then
			print("[EventController] イベント開始演出を実行:", state.eventId)
			EventUI.ShowBanner(state.eventId)
		end
		
		lastEventId = state.eventId
		lastActiveState = state.isActive
	end)

	print("[EventController] 初期化完了")
end

return EventController
