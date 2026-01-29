--// InputAutoFix.client.lua
--// ボタンクリック後の入力ブロッキングを自動的に検出・修正（安定版）

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

print("[InputAutoFix] Stable Version Active")

----------------------------------------------------------------
-- 入力ブロッキング検出 & 自動修復
----------------------------------------------------------------
local function autoFixInputBlocking()
    -- 1. キャラクターの歩行速度をチェック
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local isMovementStuck = hum and hum.WalkSpeed == 0
    
    -- アンケート中などは意図的に 0 なので除外
    local survey = PlayerGui:FindFirstChild("SurveyGui")
    local isSurveyVisible = survey and survey:FindFirstChild("Overlay") and survey.Overlay.Visible
    
    if isMovementStuck and not isSurveyVisible then
        warn("[InputAutoFix] Movement stuck detected! Repairing...")
        hum.WalkSpeed = 16
        
        -- 移動不能時のみ、原因と思われる項目をリセット
        if UserInputService.ModalEnabled then
            UserInputService.ModalEnabled = false
            warn("[InputAutoFix] ModalEnabled forced to FALSE")
        end
        
        if GuiService.SelectedObject then
            GuiService.SelectedObject = nil
            warn("[InputAutoFix] SelectedObject cleared")
        end
    end
    
    -- 2. 大きな Active=true の透明オブジェクトを定期的に掃除 (これ自体は副作用が少ない)
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("GuiObject") and obj.Active and obj.Visible then
            local size = obj.AbsoluteSize
            local screen = PlayerGui:FindFirstChildOfClass("ScreenGui") and PlayerGui:FindFirstChildOfClass("ScreenGui").AbsoluteSize or Vector2.new(1000, 1000)
            
            if size.X > screen.X * 0.8 and size.Y > screen.Y * 0.8 then
                local isTransparent = false
                if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                    isTransparent = (obj.BackgroundTransparency >= 0.95)
                elseif obj:IsA("CanvasGroup") then
                    isTransparent = (obj.GroupTransparency >= 0.95) or (obj.BackgroundTransparency >= 0.95)
                end
                
                if isTransparent then
                    warn("[InputAutoFix] Deactivating transparent blocking object:", obj:GetFullName())
                    obj.Active = false
                end
            end
        end
    end
end

----------------------------------------------------------------
-- 定期チェック（3秒ごと安全に実行）
----------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(3)
        autoFixInputBlocking()
    end
end)

-- 初期実行も少し遅らせる
task.delay(2, autoFixInputBlocking)

print("[InputAutoFix] Initialized (Safe periodic check only).")
