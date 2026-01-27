--// InputAutoFix.client.lua
--// ボタンクリック後の入力ブロッキングを自動的に検出・修正

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

print("[InputAutoFix] Active - Monitoring for input blocking issues...")

-- 状態変数
local lastClickTime = 0
local wasMoving = false

----------------------------------------------------------------
-- 入力ブロッキング検出 & 自動修復
----------------------------------------------------------------
local function autoFixInputBlocking()
    -- 1. Modal を強制解除
    if UserInputService.ModalEnabled then
        warn("[InputAutoFix] ModalEnabled was TRUE - Forcing FALSE")
        UserInputService.ModalEnabled = false
    end
    
    -- 2. SelectedObject をクリア
    if GuiService.SelectedObject then
        warn("[InputAutoFix] SelectedObject was set - Clearing")
        GuiService.SelectedObject = nil
    end
    
    -- 3. Character 状態を確認
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if root and root.Anchored then
            warn("[InputAutoFix] RootPart was ANCHORED - Unanchoring")
            root.Anchored = false
        end
        
        if hum then
            if hum.WalkSpeed == 0 then
                warn("[InputAutoFix] WalkSpeed was 0 - Restoring to 16")
                hum.WalkSpeed = 16
            end
            
            if hum.PlatformStand then
                warn("[InputAutoFix] PlatformStand was TRUE - Setting FALSE")
                hum.PlatformStand = false
            end
        end
    end
    
    -- 4. 大きな Active=true の透明フレームを無効化
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("Frame") and gui.Active and gui.Visible then
            local size = gui.AbsoluteSize
            if size.X > 500 and size.Y > 400 then
                if gui.BackgroundTransparency >= 0.95 then
                    warn("[InputAutoFix] Disabling large invisible active Frame:", gui.Name)
                    gui.Active = false
                end
            end
        end
    end
end

----------------------------------------------------------------
-- マウスクリック監視
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        lastClickTime = tick()
        
        -- クリック0.5秒後に自動修復を試行
        task.delay(0.5, function()
            autoFixInputBlocking()
        end)
    end
end)

----------------------------------------------------------------
-- 定期チェック（2秒ごと）
----------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(2)
        autoFixInputBlocking()
    end
end)

----------------------------------------------------------------
-- キャラクター変更時に状態をリセット
----------------------------------------------------------------
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    autoFixInputBlocking()
end)

print("[InputAutoFix] Initialized Successfully")
