--// ReplicatedStorage/Shared/Config/PromotionConfig.lua

local PromotionConfig = {}

-- フィードバック報酬 (👍 YES)
PromotionConfig.FeedbackReward = {
	Amount = 1000, -- コイン報酬額
	PromptText = "Smash Ride、楽しんでる？",
	YesButtonText = "👍 YES",
	ClaimedText = "CLAIMED",
}

-- コミュニティ報酬 (🌈 Rainbow Hammer)
PromotionConfig.CommunityReward = {
	GroupId = 743732162, -- VIRTUAL-G Group ID
	DisplayName = "限定🌈レインボーハンマー！",
	PromptText = "グループに参加 & ゲームにいいねで",
	JoinPromptText = "🌈レインボーハンマーをゲット！\n(参加 & いいね後、ロビーに戻ると受け取れます)",
	CongratsText = "🎉 グループ参加 & いいねありがとう！",
	HammerId = "RAINBOW",
	ActionText = "🌈 JOIN",
}

return PromotionConfig
