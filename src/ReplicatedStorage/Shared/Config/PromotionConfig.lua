-- PromotionConfig.lua
-- プロモーション（いいね＆グループ参加）設定

local PromotionConfig = {}

PromotionConfig.CommunityReward = {
	MinLikes = 0,
	GroupId = 220606963,
	TriggerId = "PROMO_CHECK", -- (Netで叩く用)
	JoinPromptText = "グループに参加して特典をゲット!", -- プロンプト表示用テキスト
	HammerId = "RAINBOW",
	CongratsText = "🎉 グループ参加 & いいねありがとう！",
}

-- フィードバック/いいね報酬設定
PromotionConfig.FeedbackReward = {
	Amount = 100, -- 付与するスクラップ量
	Message = "👍 THANKS! コインを獲得しました!",
	PromptText = "ゲームに「いいね」を押して\n100コインをゲット!",
	YesButtonText = "👍 いいね & 受け取る",
	ClaimedText = "✅ 受け取り済み",
}

-- UI 表示用設定
PromotionConfig.UI = {
	Title = "GROUP REWARDS",
	Desc = "グループ参加 & ゲームへの「いいね」で\n限定ハンマーをゲット！\n(既に完了している場合は自動で付与されます)",
	CongratsText = "🎉 グループ参加 & いいねありがとう！",
	HammerId = "RAINBOW",
	ActionText = "🌈 JOIN",
}

return PromotionConfig
