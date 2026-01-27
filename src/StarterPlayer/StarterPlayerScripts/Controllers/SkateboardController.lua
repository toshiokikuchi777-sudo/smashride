-- StarterPlayer/StarterPlayerScripts/Controllers/SkateboardController.lua
-- スケボーアイテムのクライアント側処理

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local SkateboardController = {}

local player = Players.LocalPlayer
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local SkateboardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SkateboardConfig"))

-- スケボーの状態
local isEquipped = false

-- HUDを取得
local function getHud()
    local pg = player:WaitForChild("PlayerGui", 10)
    if not pg then return nil end
    return pg:WaitForChild("MainHud", 10)
end

-- スケボーをトグル
function SkateboardController.ToggleSkateboard()
    print("[SkateboardController] Toggle skateboard")
    local ToggleSkateboardEvent = Net.E("ToggleSkateboard")
    ToggleSkateboardEvent:FireServer()
end

-- UI更新
local function updateUI(equipped)
    local hud = getHud()
    if not hud then return end
    
    local skateboardButton = hud:FindFirstChild("SkateboardButton", true)
    if not skateboardButton then return end
    
    -- ボタンの色を変更
    if equipped then
        skateboardButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)  -- 緑（装備中）
    else
        skateboardButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)  -- 青（未装備）
    end
    
    -- テキスト更新
    local label = skateboardButton:FindFirstChild("Label")
    if label then
        label.Text = equipped and "🛹 ON" or "🛹 OFF"
    end
end

-- 初期化
function SkateboardController.Init()
    print("[SkateboardController] Init")
    
    local ToggleSkateboardEvent = Net.E("ToggleSkateboard")
    local SkateboardStateSync = Net.E("SkateboardStateSync")
    
    -- アニメーション設定 (R15 MainModule由来)
    local ANIM_IDS = {
        Coasting = "rbxassetid://886940305",
        Ollie = "rbxassetid://742702208",
        LeftTurn = "rbxassetid://886947598",
        RightTurn = "rbxassetid://886948191",
        Kick = "rbxassetid://742703564"
    }
    
    -- サウンド設定
    local SOUND_IDS = {
        CruiseLoop = "rbxassetid://96481249", -- ロードノイズ
        Ollie = "rbxassetid://22921446",      -- ジャンプ音
        Drop = "rbxassetid://22920550"       -- 着地音
    }

    local activeTracks = {}
    local activeSounds = {}
    local currentMainAnim = nil
    -- スケボーの状態
    local isEquipped = false
    local originalRootC0 = nil
    
    local renderConn = nil
    local jumpingConn = nil

    local function stopPose()
        for i, track in pairs(activeTracks) do
            track:Stop(0.2)
        end
        table.clear(activeTracks)
        currentMainAnim = nil
        
        if renderConn then
            renderConn:Disconnect()
            renderConn = nil
        end
        if jumpingConn then
            jumpingConn:Disconnect()
            jumpingConn = nil
        end

        for i, sound in pairs(activeSounds) do
            sound:Stop()
        end
        table.clear(activeSounds)
        
        local character = player.Character
        local rootPart = character and (character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso"))
        local rootJoint = rootPart and (rootPart:FindFirstChild("Root") or rootPart:FindFirstChild("RootJoint"))
        if rootJoint and originalRootC0 then
            rootJoint.C0 = originalRootC0
        end
        print("[SkateboardController] All actions stopped and Root reset")
    end

    local function setupAnimations(humanoid)
        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
        for name, id in pairs(ANIM_IDS) do
            local anim = Instance.new("Animation")
            anim.AnimationId = id
            local success, track = pcall(function()
                return animator:LoadAnimation(anim)
            end)
            if success and track then
                track.Priority = (name == "Ollie") and Enum.AnimationPriority.Action4 or Enum.AnimationPriority.Action
                track.Looped = (name ~= "Ollie" and name ~= "Kick")
                activeTracks[name] = track
            else
                warn("[SkateboardController] Failed to load animation:", name, id)
            end
        end
    end

    local function setupSounds(rootPart)
        for name, id in pairs(SOUND_IDS) do
            local sound = Instance.new("Sound")
            sound.Name = name
            sound.SoundId = id
            sound.Looped = (name == "CruiseLoop")
            -- 走行音以外は初期音量を設定、走行音は updateCruiseSound で管理
            sound.Volume = (name == "CruiseLoop") and 0 or 0.5
            sound.Parent = rootPart
            activeSounds[name] = sound
        end
    end

    local function updateCruiseSound(humanoid)
        local sound = activeSounds.CruiseLoop
        if not sound then return end

        local isFalling = humanoid:GetState() == Enum.HumanoidStateType.Freefall or humanoid:GetState() == Enum.HumanoidStateType.Jumping
        if isFalling then
            sound.Volume = math.max(0, sound.Volume - 0.1)
            return
        end

        local speed = humanoid.RootPart.Velocity.Magnitude
        if speed > 1 then
            if not sound.IsPlaying then sound:Play() end
            -- 速度に応じて音量とピッチをわずかに変更 (Max 0.5)
            sound.Volume = math.clamp(speed / 40 * 0.5, 0, 0.5)
            sound.PlaybackSpeed = math.clamp(0.8 + (speed / 40 * 0.4), 0.8, 1.2)
        else
            sound.Volume = math.max(0, sound.Volume - 0.05)
            if sound.Volume <= 0 and sound.IsPlaying then
                sound:Stop()
            end
        end
    end

    -- キャラクター交代時のクリーンアップ
    player.CharacterAdded:Connect(function(char)
        stopPose()
        originalRootC0 = nil
    end)

    SkateboardStateSync.OnClientEvent:Connect(function(equipped)
        print("[SkateboardController] State synced:", equipped)
        isEquipped = equipped
        updateUI(equipped)
        
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        if equipped then
            stopPose()
            setupAnimations(humanoid)
            
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then setupSounds(rootPart) end
            
            local lowerTorso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
            local rootJoint = lowerTorso and (lowerTorso:FindFirstChild("Root") or lowerTorso:FindFirstChild("RootJoint"))
            
            if rootJoint then
                if not originalRootC0 then originalRootC0 = rootJoint.C0 end
                
                -- 定常ポーズ開始
                if activeTracks.Coasting then
                    activeTracks.Coasting:Play()
                    currentMainAnim = "Coasting"
                end

                -- ジャンプ検知 (StateChanged の方が確実)
                jumpingConn = humanoid.StateChanged:Connect(function(old, new)
                    if new == Enum.HumanoidStateType.Jumping then
                        if activeTracks.Ollie then
                            activeTracks.Ollie:Play(0.05)
                            activeTracks.Ollie:AdjustSpeed(1.8) -- 1.8倍速でキビキビ動かす
                            if activeSounds.Ollie then activeSounds.Ollie:Play() end
                            print("[SkateboardController] Action: Ollie! (Speed 1.8)")
                        end
                    elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.RunningNoPhysics then
                        -- 着地を検知 (Freefallからの着地)
                        if old == Enum.HumanoidStateType.Freefall or old == Enum.HumanoidStateType.Jumping then
                            print("[SkateboardController] Landed!")
                            if activeSounds.Drop then activeSounds.Drop:Play() end
                        end
                        -- 地面に着いたらオーリーを強制終了
                        if activeTracks.Ollie and activeTracks.Ollie.IsPlaying then
                            activeTracks.Ollie:Stop(0.1)
                            print("[SkateboardController] Ollie stopped on landing")
                        end
                    end
                end)

                -- 状態更新ループ
                if renderConn then renderConn:Disconnect() end
                renderConn = RunService.RenderStepped:Connect(function()
                    if not isEquipped or not character:FindFirstChild("Humanoid") then
                        stopPose()
                        return
                    end

                    -- Rootオフセット適用 (オーリー再生中はアニメーションに任せて固定を解除)
                    local isOlliePlaying = activeTracks.Ollie and activeTracks.Ollie.IsPlaying
                    if rootJoint and originalRootC0 then
                        if isOlliePlaying then
                            -- ジャンプ中は位置（高さ）の強制固定を解除し、アニメーションに任せる
                            -- ただしサイドスタンスを維持（オーリーアニメの回転を考慮して0度に調整）
                            rootJoint.C0 = originalRootC0 * CFrame.Angles(0, math.rad(0), 0)
                        else
                            rootJoint.C0 = originalRootC0 * ROOT_OFFSET
                        end
                    end

                    -- サウンド更新
                    updateCruiseSound(humanoid)

                    -- 旋回・移動アニメーションのブレンド
                    local moveDir = humanoid.MoveDirection
                    if moveDir.Magnitude > 0.1 then
                        -- キャラクターの右方向ベクトルとの内積で旋回量を計算
                        local rightVec = rootPart.CFrame.RightVector
                        local turnFactor = moveDir:Dot(rightVec) -- 正:右、負:左
                        
                        -- ウェイト調整 (0.2秒で遷移)
                        if turnFactor > 0.3 then
                            if activeTracks.RightTurn then activeTracks.RightTurn:Play(0.2, 1) end
                            if activeTracks.LeftTurn then activeTracks.LeftTurn:Stop(0.2) end
                            if activeTracks.Coasting then activeTracks.Coasting:AdjustWeight(0.5, 0.2) end
                        elseif turnFactor < -0.3 then
                            if activeTracks.LeftTurn then activeTracks.LeftTurn:Play(0.2, 1) end
                            if activeTracks.RightTurn then activeTracks.RightTurn:Stop(0.2) end
                            if activeTracks.Coasting then activeTracks.Coasting:AdjustWeight(0.5, 0.2) end
                        else
                            if activeTracks.LeftTurn then activeTracks.LeftTurn:Stop(0.2) end
                            if activeTracks.RightTurn then activeTracks.RightTurn:Stop(0.2) end
                            if activeTracks.Coasting then activeTracks.Coasting:AdjustWeight(1, 0.2) end
                        end
                    else
                        -- 静止時
                        if activeTracks.LeftTurn then activeTracks.LeftTurn:Stop(0.2) end
                        if activeTracks.RightTurn then activeTracks.RightTurn:Stop(0.2) end
                        if activeTracks.Coasting then activeTracks.Coasting:AdjustWeight(1, 0.2) end
                    end
                end)
            end
        else
            stopPose()
        end
    end)
    
    -- キーボード入力（Qキー）
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.Q then
            SkateboardController.ToggleSkateboard()
        end
    end)
    
    -- UI設定
    task.spawn(function()
        local hud = getHud()
        if not hud then return end
        
        local skateboardButton = hud:FindFirstChild("SkateboardButton", true)
        if skateboardButton then
            skateboardButton.Activated:Connect(function()
                SkateboardController.ToggleSkateboard()
            end)
            
            -- 初期状態を反映
            updateUI(isEquipped)
        else
            print("[SkateboardController] SkateboardButton not found in UI")
        end
    end)
end

return SkateboardController
