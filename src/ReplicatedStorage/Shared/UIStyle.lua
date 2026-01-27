-- ReplicatedStorage/Shared/UIStyle.lua
local TweenService = game:GetService("TweenService")

local UIStyle = {}

-- Flashy Button Style Definition
-- Flashy Button Style Definition
local FLASHY_STYLE = {
    Gradient = {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)), -- Gold center
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 0)),
        }),
        Rotation = 90,
    },
    Stroke = {
        Thickness = 4,
        Color = Color3.fromRGB(255, 255, 255),
    }
}

-- Applies "Flashy" style to a button
function UIStyle.ApplyFlashy(button)
    if not button then return end

    -- 0. Basic Properties (Font, TextColor)
    button.Font = Enum.Font.RobotoMono
    button.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    -- Text Stroke for readability against bright background
    button.TextStrokeTransparency = 0
    button.TextStrokeColor3 = Color3.fromRGB(150, 100, 0) -- Dark gold/brown text stroke
    
    -- 1. Add UICorner (if not exists)
    local corner = button:FindFirstChildOfClass("UICorner")
    if not corner then
        corner = Instance.new("UICorner")
        corner.Name = "FlashyCorner"
        corner.CornerRadius = UDim.new(0.3, 0) -- Nice round buttons
        corner.Parent = button
    end

    -- 2. Add UIGradient (Rich Gold)
    local grad = button:FindFirstChildOfClass("UIGradient")
    if not grad then
        grad = Instance.new("UIGradient")
        grad.Name = "FlashyGradient"
        grad.Parent = button
    end
    
    grad.Color = FLASHY_STYLE.Gradient.Color
    grad.Rotation = 90 -- Vertical gradient for depth

    -- 3. Add UIStroke (White Border) - DISABLED
    --[[
    local stroke = button:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Name = "FlashyStroke"
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = button
    end
    stroke.Thickness = FLASHY_STYLE.Stroke.Thickness
    stroke.Color = FLASHY_STYLE.Stroke.Color
    ]]
    
    -- 4. Dynamic "Shine" Animation (Overlay Gradient)
    -- We'll create a Frame inside to act as the shine container to not mess up the main gradient
    local shineFrame = button:FindFirstChild("ShineFrame")
    if not shineFrame then
        shineFrame = Instance.new("Frame")
        shineFrame.Name = "ShineFrame"
        shineFrame.Size = UDim2.new(1, 0, 1, 0)
        shineFrame.BackgroundTransparency = 1
        shineFrame.ZIndex = button.ZIndex + 1
        shineFrame.Parent = button
        
        local shineCorner = corner:Clone()
        shineCorner.Parent = shineFrame
        
        local shineGrad = Instance.new("UIGradient")
        shineGrad.Name = "ShineGradient"
        shineGrad.Color = ColorSequence.new(Color3.new(1,1,1))
        shineGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.4, 1),
            NumberSequenceKeypoint.new(0.5, 0.4), -- Flash point
            NumberSequenceKeypoint.new(0.6, 1),
            NumberSequenceKeypoint.new(1, 1),
        })
        shineGrad.Rotation = 45
        shineGrad.Parent = shineFrame
        
        -- Animation loop
        task.spawn(function()
            while button and button.Parent do
                local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local tween = TweenService:Create(shineGrad, tweenInfo, {Offset = Vector2.new(1, 0)})
                shineGrad.Offset = Vector2.new(-1, 0)
                tween:Play()
                task.wait(3 + math.random()) -- Random interval for natural feel
            end
        end)
    end
    
    -- 5. Mouse Interaction (Hover Effects)
    -- Use UIScale to avoid layout issues
    local uiScale = button:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = Instance.new("UIScale")
        uiScale.Name = "HoverScale"
        uiScale.Scale = 1.0
        uiScale.Parent = button
    end
    
    button.MouseEnter:Connect(function()
        -- Scale up slightly
        local scaleTween = TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.08})
        scaleTween:Play()
        
        -- Brighten stroke - DISABLED (stroke is nil)
        --[[
        local stroke = button:FindFirstChildOfClass("UIStroke")
        if stroke then
            local strokeTween = TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(255, 230, 100)})
            strokeTween:Play()
        end
        ]]
        
        -- Slightly reduce transparency for "pop" effect
        if button.BackgroundTransparency < 0.9 then
            local bgTween = TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = math.max(0, button.BackgroundTransparency - 0.1)})
            bgTween:Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        -- Return to normal scale
        local scaleTween = TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.0})
        scaleTween:Play()
        
        -- Restore stroke color - DISABLED (stroke is nil)
        --[[
        local stroke = button:FindFirstChildOfClass("UIStroke")
        if stroke then
            local strokeTween = TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(255, 255, 255)})
            strokeTween:Play()
        end
        ]]
        
        -- Restore transparency
        if button.BackgroundTransparency < 0.9 then
            local bgTween = TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = math.min(1, button.BackgroundTransparency + 0.1)})
            bgTween:Play()
        end
    end)
end

-- Applies "Locked" style to a button (for disabled/locked states)
function UIStyle.ApplyLocked(button)
    if not button then return end
    
    -- Dark gray background
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.AutoButtonColor = false
    
    -- Muted text
    button.TextColor3 = Color3.fromRGB(150, 150, 150)
    button.Font = Enum.Font.RobotoMono
    button.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    
    -- Dark stroke - DISABLED
    --[[
    local stroke = button:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Name = "LockedStroke"
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = button
    end
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(40, 40, 40)
    ]]
    -- stroke.Transparency = 0.3 -- This line was commented out as part of the stroke block.
    
    -- Add corner if not exists
    local corner = button:FindFirstChildOfClass("UICorner")
    if not corner then
        corner = Instance.new("UICorner")
        corner.Name = "LockedCorner"
        corner.CornerRadius = UDim.new(0.2, 0)
        corner.Parent = button
    end
end

-- Rarity Colors
UIStyle.RarityColors = {
    Common    = Color3.fromRGB(200, 200, 200),
    Uncommon  = Color3.fromRGB(50, 200, 50),
    Rare      = Color3.fromRGB(50, 150, 255),
    Epic      = Color3.fromRGB(180, 50, 255),
    Legendary = Color3.fromRGB(255, 200, 50),
}

-- Row Styles
UIStyle.RowBackground = Color3.fromRGB(50, 50, 60)
UIStyle.RowCornerRadius = UDim.new(0, 8)

-- Equipment Colors
UIStyle.EquipColor = Color3.fromRGB(200, 80, 80) -- Red-ish (Unequip)
UIStyle.UnequipColor = Color3.fromRGB(80, 200, 80) -- Green-ish (Equip)

return UIStyle
