local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

print("[Diagnostic] ACTIVE. Monitoring Client State...")

----------------------------------------------------------------
-- 1. ZIndex Auto-Fix & Blocker Detection
----------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(2.0)
        local hud = PlayerGui:FindFirstChild("MainHud")
        if hud then
            -- Force Buttons to Top
            for _, obj in ipairs(hud:GetDescendants()) do
                if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                    if obj.ZIndex < 100 then
                        obj.ZIndex = 100
                        print("[Diagnostic] Bumped ZIndex for:", obj.Name)
                    end
                end
            end
            
            -- Detect Blockers
            -- Check for FullScreen Frames that are Active=true
            -- (Screen size approx 800x600 min, we just check Relative Size)
        end
        
        -- Check Modal
        if UserInputService.ModalEnabled then
             warn("[Diagnostic] ALERT: UserInputService.ModalEnabled is TRUE (Mouse Locked?)")
        end
        
        -- Check Focus
        local sel = GuiService.SelectedObject
        if sel then
             warn("[Diagnostic] ALERT: GuiService.SelectedObject is set to:", sel:GetFullName())
        end
    end
end)

----------------------------------------------------------------
-- 2. Character State
----------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(3.0)
        local char = player.Character
        if not char then
            warn("[Diagnostic] Character is NIL")
        else
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            if root and root.Anchored then
                warn("[Diagnostic] Character Root is ANCHORED (Cannot Move)")
            end
            if hum and hum.WalkSpeed == 0 then
                warn("[Diagnostic] Humanoid WalkSpeed is 0")
            end
        end
    end
end)

----------------------------------------------------------------
-- 3. Input Monitor (Do inputs exist?)
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        print("[Diagnostic] Input Registered! GPE:", gpe)
    end
    if input.KeyCode == Enum.KeyCode.W then
         print("[Diagnostic] Movement Key W Pressed. GPE:", gpe)
    end
end)
