-- ReplicatedStorage/Shared/Config/SkateboardConfig.lua
-- スケボーアイテムの設定

local SkateboardConfig = {}

-- スピード設定
SkateboardConfig.NormalWalkSpeed = 16  -- 通常の歩行速度
SkateboardConfig.SkateboardWalkSpeed = 32  -- スケボー使用時の速度
SkateboardConfig.SpeedMultiplier = 2.0  -- 速度倍率

-- スケボーの種類（将来の拡張用）
SkateboardConfig.Types = {
    BASIC = {
        name = "Basic Skateboard",
        speedMultiplier = 2.0,
        unlocked = true,  -- 初期解放
    },
    -- 将来追加予定
    -- SPEED = {
    --     name = "Speed Skateboard",
    --     speedMultiplier = 2.5,
    --     unlocked = false,
    --     unlockCondition = { cansSmashedTotal = 100 }
    -- },
    -- TURBO = {
    --     name = "Turbo Skateboard",
    --     speedMultiplier = 3.0,
    --     unlocked = false,
    --     unlockCondition = { cansSmashedTotal = 500 }
    -- }
}

-- 自動解除設定
SkateboardConfig.AutoUnequip = {
    onJump = false,      -- ジャンプ時に解除するか
    onCanSmash = false,  -- 缶破壊時に解除するか
    onDeath = true,      -- 死亡時に解除するか
}

-- アニメーション設定（将来の拡張用）
SkateboardConfig.Animation = {
    enabled = false,
    animationId = "",  -- Roblox Animation ID
}

return SkateboardConfig
