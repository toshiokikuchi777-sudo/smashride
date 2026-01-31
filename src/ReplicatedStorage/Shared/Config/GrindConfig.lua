-- ReplicatedStorage/Shared/Config/GrindConfig.lua
-- レールグラインドシステムの設定

local GrindConfig = {}

-- レール検出設定
GrindConfig.DetectionRadius = 8 -- レール検出の半径（studs）
GrindConfig.DetectionHeight = 10 -- レール検出の高さ範囲（studs）
GrindConfig.MinimumRailLength = 5 -- グラインド可能な最小レール長（studs）

-- グラインド物理設定
GrindConfig.GrindSpeed = 40 -- グラインド中の移動速度（studs/秒）
GrindConfig.GrindAcceleration = 20 -- グラインド開始時の加速度
GrindConfig.GrindFriction = 0.95 -- グラインド中の摩擦係数（1.0 = 摩擦なし）
GrindConfig.SnapToRailStrength = 0.5 -- レールに吸着する強さ（0-1）強化！

-- ジャンプ離脱設定
GrindConfig.JumpOffUpwardForce = 35 -- ジャンプ離脱時の上向き力(調整済み)
GrindConfig.JumpOffForwardForce = 25 -- ジャンプ離脱時の前方向力(調整済み)
GrindConfig.JumpOffCooldown = 0.5 -- ジャンプ後の再グラインド可能までの時間(秒)

-- グラインド終了条件
GrindConfig.MaxDistanceFromRail = 15 -- レールから離れる最大距離（studs）CFrame移動対応！
GrindConfig.MinGrindDuration = 0.2 -- 最小グラインド時間（秒）

-- エフェクト設定
GrindConfig.SparkEffectEnabled = true -- 火花エフェクトを有効化
GrindConfig.GrindSoundEnabled = true -- グラインド音を有効化
GrindConfig.GrindSoundId = "rbxassetid://96481249" -- スケボー走行音と同じIDに変更

-- レールタグ
GrindConfig.RailTag = "GRIND_RAIL" -- CollectionServiceで使用するタグ名

return GrindConfig
