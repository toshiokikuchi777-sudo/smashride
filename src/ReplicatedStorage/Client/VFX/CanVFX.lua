-- ReplicatedStorage/Client/VFX/CanVFX.lua
-- 演出・音を全部ここに集約
-- 最終刷新版：究極のショックウェーブ演出 (PointLight, Huge Dome, Pillar of Light)
-- TS: 22:01 (Strict Robust Version)

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CanVFX = {}

-- =========================
-- 🎨 色定義
-- =========================
local COLORS = {
	BASIC      = Color3.fromRGB(255,   0,   0),
	SHOCKWAVE  = Color3.fromRGB( 50, 150, 255), -- オレンジから青に変更
	MULTI      = Color3.fromRGB(  0, 255,   0),
	HYBRID     = Color3.fromRGB(180,   0, 255),
	CAN_CRUSH  = Color3.fromRGB(255, 255,   0),
	ORB        = Color3.fromRGB(255, 255, 200),
}

-- =========================
-- 🛠 内部ユーティリティ
-- =========================
local function createNeonPart(size, cframe, color, shape)
	local p = Instance.new("Part")
	p.Name = "VFX_Part"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Shape = shape or Enum.PartType.Block
	p.Parent = workspace
	return p
end

local function tweenOut(inst, tweenInfo, props)
	local tw = TweenService:Create(inst, tweenInfo, props)
	tw:Play()
	Debris:AddItem(inst, tweenInfo.Time + 0.1)
end

-- =========================
-- ✨ メイン演出: 円形放射 (Hit/Shockwave)
-- =========================
function CanVFX.PlayHammerHitVFX(hammerType, worldPos, isBig)
	-- [STABILITY] worldPos が nil なら終了
	if not worldPos then return end
	
	print("[CanVFX.PlayHammerHitVFX] CALLED! Type:", hammerType, "isBig:", isBig)
	
	local hType = tostring(hammerType or "BASIC"):upper()
	local color = COLORS[hType] or COLORS.BASIC
	
	local duration = (isBig == true) and 1.5 or 0.6
	local ringSize = (isBig == true) and 45 or 12
	local effectHeight = (isBig == true) and 0.5 or 2.0
	local centerPos = worldPos + Vector3.new(0, effectHeight, 0)
	-- [SAFETY] Ensure visuals are never buried underground (Y floor)
	if centerPos.Y < 2.0 then
		centerPos = Vector3.new(centerPos.X, 2.0, centerPos.Z)
	end
	
	-- 0) FLASH
	local flashSize = (isBig == true) and 25 or 6
	local flash = createNeonPart(Vector3.new(0.5, 0.5, 0.5), CFrame.new(centerPos), Color3.new(1,1,1), Enum.PartType.Ball)
	
	tweenOut(flash, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
		Size = Vector3.new(flashSize, flashSize, flashSize),
		Transparency = 1
	})
	
	-- 1) 地面の巨大リング (ショックウェーブ)
	local ring = createNeonPart(Vector3.new(1.0, 0.5, 0.5), CFrame.new(centerPos) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	ring.Transparency = 0.1
	tweenOut(ring, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, ringSize, ringSize),
		Transparency = 1
	})

	-- 2) 外側に飛び出すレイ
	local rayCount = (isBig == true) and 40 or 12
	local rayLength = (isBig == true) and 30 or 8
	for i = 1, rayCount do
		local ang = (i / rayCount) * math.pi * 2
		local dir = Vector3.new(math.cos(ang), 0.05, math.sin(ang)).Unit
		local rayPos = centerPos + dir * 1.0
		
		-- [STABILITY] CFrame.lookAt を使用
		local ray = createNeonPart(Vector3.new(0.5, 0.5, (isBig == true) and 5 or 2), CFrame.lookAt(rayPos, rayPos + dir), color)
		tweenOut(ray, TweenInfo.new(duration * 0.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(centerPos + dir * rayLength, centerPos + dir * (rayLength + 1)),
			Size = Vector3.new(0.01, 0.01, (isBig == true) and 10 or 3),
			Transparency = 1
		})
	end

	-- 3) [ULTIMATE SHOCKWAVE] 特大演出
	if isBig == true then
		-- A) 巨大なドーム
		local dome = createNeonPart(Vector3.new(5, 5, 5), CFrame.new(centerPos), color, Enum.PartType.Ball)
		dome.Transparency = 0.4
		tweenOut(dome, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = Vector3.new(ringSize * 0.9, ringSize * 0.9, ringSize * 0.9),
			Transparency = 1
		})

		-- B) 空へ伸びる光の柱 (Z軸で90度回転させて垂直に)
		local pillar = createNeonPart(Vector3.new(5, 5, 5), CFrame.new(centerPos) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
		pillar.Transparency = 0.3
		tweenOut(pillar, TweenInfo.new(3.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = Vector3.new(150, 2, 2),
			Transparency = 1
		})

		-- C) セカンド衝撃波
		task.delay(0.15, function()
			local ring2 = createNeonPart(Vector3.new(1.5, 1, 1), CFrame.new(centerPos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1,1,1), Enum.PartType.Cylinder)
			ring2.Transparency = 0.5
			tweenOut(ring2, TweenInfo.new(1.0, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.05, ringSize * 1.4, ringSize * 1.4),
				Transparency = 1
			})
		end)
	end
end

-- =========================
-- 🥫 缶破砕演出
-- =========================
function CanVFX.PlayCanCrushVFX(canModel, worldPos, targetCharacter)
	if not worldPos then return end
	if canModel and canModel:GetAttribute("VFX_Played") then 
        -- print("[CanVFX] VFX already played for:", canModel.Name)
        return 
    end
	if canModel then canModel:SetAttribute("VFX_Played", true) end
    
    -- print("[CanVFX] PlayCanCrushVFX for:", canModel and canModel.Name or "Unknown")

	local color = COLORS.CAN_CRUSH
	local dur = 0.4
	local p = createNeonPart(Vector3.new(0.5, 0.2, 0.2), CFrame.new(worldPos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	tweenOut(p, TweenInfo.new(dur, Enum.EasingStyle.Quart), { Size = Vector3.new(0.01, 8, 8), Transparency = 1 })

	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	local localChar = localPlayer and localPlayer.Character
	
    -- オーブを表示するかどうかの決定ロジックを緩和
    -- targetCharacter が渡されていれば、そのキャラクターを目標にする
    if not targetCharacter then 
        return 
    end

    -- 念のため目標キャラクターが有効かチェック
    local function getTargetPos(char)
        if not char or not char.Parent then return nil end
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart", true)
        return root and root.Position
    end
    
    if not getTargetPos(targetCharacter) then return end

    -- print("[CanVFX] Creating Orb for:", localPlayer.Name)

	task.spawn(function()
		local orb = createNeonPart(Vector3.new(2, 2, 2), CFrame.new(worldPos), COLORS.ORB, Enum.PartType.Ball)
		orb.Transparency = 0.1
		local attachment = Instance.new("Attachment", orb)
		local particle = Instance.new("ParticleEmitter", attachment)
		particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particle.Color = ColorSequence.new(COLORS.ORB)
		particle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
		particle.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
		particle.Lifetime = NumberRange.new(0.4, 0.6)
		particle.Rate = 75
		particle.Speed = NumberRange.new(0, 0)
		particle.Brightness = 1.5
		particle.LightEmission = 0.8
		particle.Enabled = true

		local startTime = tick()
		local durMove = 0.6
		local startPos = worldPos
		local midOffset = Vector3.new(math.random(-5, 5), math.random(10, 15), math.random(-5, 5))
		local function getBack(char)
			local root = char:FindFirstChild("HumanoidRootPart")
			return root and (root.Position + Vector3.new(0, 1, 0))
		end
		while (tick() - startTime) < durMove do
			local t = (tick() - startTime) / durMove
			local endPos = getTargetPos(targetCharacter) or startPos
			local mid = (startPos + endPos) / 2 + midOffset
			local pos = (1 - t)^2 * startPos + 2 * (1 - t) * t * mid + t^2 * endPos
			orb.CFrame = CFrame.new(pos)
			RunService.RenderStepped:Wait()
		end
		orb:Destroy()
	end)
end

-- =========================
-- 🔊 音
-- =========================
function CanVFX.PlayHitSound(handle, canModel)
	local sounds = ReplicatedStorage:FindFirstChild("Sounds")
	local sound = (canModel and canModel:FindFirstChild("CrushSound")) or (sounds and sounds:FindFirstChild("CanCrush"))
	if sound then
		local s = sound:Clone()
		s.Parent = workspace
		s:Play()
		Debris:AddItem(s, 2)
	end
end

-- フェイスターゲット撃破時の豪華なサウンド
function CanVFX.PlayFaceClearSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://3521543186" -- 被弾音と同じ
	sound.Volume = 1.0
	sound.Parent = workspace
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- フェイスターゲット被弾時のサウンド
function CanVFX.PlayFaceHitSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://3521543186"
	sound.Volume = 0.6
	sound.Parent = workspace
	sound:Play()
	Debris:AddItem(sound, 2)
end

-- モデルをフェードアウトさせて消す演出
function CanVFX.FadeOutModel(model, duration)
	if not model then return end
	local ti = TweenInfo.new(duration or 2, Enum.EasingStyle.Linear)
	
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			TweenService:Create(part, ti, { Transparency = 1 }):Play()
		elseif part:IsA("Decal") or part:IsA("Texture") then
			TweenService:Create(part, ti, { Transparency = 1 }):Play()
		elseif part:IsA("BillboardGui") then
			-- 特別にHPバーなどを消す
			TweenService:Create(part, ti, { Size = UDim2.new(0, 0, 0, 0) }):Play()
		end
	end
end

-- 被弾時のヒットフラッシュ演出
function CanVFX.PlayFaceHitFlash(model)
	if not model then 
		warn("[CanVFX.PlayFaceHitFlash] Model is nil!")
		return 
	end
	
	print("[CanVFX.PlayFaceHitFlash] Called for:", model.Name)
	
	local highlight = model:FindFirstChild("HitHighlight")
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "HitHighlight"
		highlight.FillColor = Color3.new(1, 1, 1)
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 1
		highlight.Adornee = model
		highlight.Parent = model
		print("[CanVFX.PlayFaceHitFlash] Created new Highlight for:", model.Name)
	end
	
	-- フラッシュ開始
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0
	print("[CanVFX.PlayFaceHitFlash] Flash started for:", model.Name)
	
	-- Tweenで戻す
	local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(highlight, ti, {
		FillTransparency = 1,
		OutlineTransparency = 1
	}):Play()
end

-- 被弾時のシェイク（揺れ）演出
function CanVFX.ShakeFace(model)
	if not model or not model:IsA("Model") then return end
	
	-- すでに揺れている場合は重ならないようにする
	if model:GetAttribute("IsShaking") then return end
	model:SetAttribute("IsShaking", true)
	
	local originalPivot = model:GetPivot()
	local shakeIntensity = 0.6
	local shakeDuration = 0.05
	
	task.spawn(function()
		-- 3回小刻みに揺らす
		for i = 1, 3 do
			local offset = Vector3.new(
				(math.random() - 0.5) * shakeIntensity,
				(math.random() - 0.5) * shakeIntensity,
				(math.random() - 0.5) * shakeIntensity
			)
			model:PivotTo(originalPivot * CFrame.new(offset))
			task.wait(shakeDuration)
		end
		
		-- 元に戻す
		model:PivotTo(originalPivot)
		model:SetAttribute("IsShaking", nil)
	end)
end

-- =========================
-- 互換 & 整理
-- =========================
function CanVFX.PlayShockwaveLocalFlash(hammerType) return COLORS[tostring(hammerType):upper()] or COLORS.SHOCKWAVE end
function CanVFX.PlayShockwaveWorld(pos, rad, col, hammerType)
	CanVFX.PlayHammerHitVFX(hammerType or "SHOCKWAVE", pos, true)
end

function CanVFX.PlayMultiplierPopup(canColor, multiplier)
	local lp = game:GetService("Players").LocalPlayer
	local char = lp.Character
	if not char or not char:FindFirstChild("Head") then return end
	local bg = Instance.new("BillboardGui", lp:WaitForChild("PlayerGui"))
	bg.Adornee = char.Head
	bg.Size = UDim2.new(5, 0, 2.5, 0)
	bg.StudsOffset = Vector3.new(0, 3, 0)
	local txt = Instance.new("TextLabel", bg)
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.BackgroundTransparency = 1
	txt.Text = string.format("x%.1f!", multiplier)
	txt.TextColor3 = COLORS[tostring(canColor):upper()] or Color3.new(1,1,1)
	txt.Font = Enum.Font.FredokaOne
	txt.TextScaled = true
	TweenService:Create(bg, TweenInfo.new(1.2, Enum.EasingStyle.Quart), {StudsOffset = Vector3.new(0, 7, 0)}):Play()
	TweenService:Create(txt, TweenInfo.new(1.2), {TextTransparency = 1}):Play()
	Debris:AddItem(bg, 1.4)
end

----------------------------------------------------------------
-- ロック演出（壊せない缶）
----------------------------------------------------------------
local LOCK_SOUND_ID = "rbxassetid://95979206644077"
local LOCK_COOLDOWN = 0.25
local lockCache = {}

function CanVFX.PlayLockedVFX(worldPos, canModel)
	CanVFX.PlayReasonVFX(canModel, "NEED STRONG HAMMER", Color3.fromRGB(255, 80, 80))
end

function CanVFX.PlayReasonVFX(canModel, reason, color)
	if not canModel or not canModel.Parent then return end
	
	local last = lockCache[canModel]
	if last and tick() - last < LOCK_COOLDOWN then return end
	lockCache[canModel] = tick()

	-- Sound 生生成
	local sound = Instance.new("Sound")
	sound.SoundId = LOCK_SOUND_ID
	sound.Volume = 0.5
	sound.Parent = workspace
	sound:Play()
	Debris:AddItem(sound, 1)

	local color = color or Color3.fromRGB(255, 255, 255)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(8, 2)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = canModel.PrimaryPart or canModel:FindFirstChildWhichIsA("BasePart", true)
	gui.Parent = workspace

	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Text = tostring(reason)
	txt.TextColor3 = color
	txt.TextStrokeTransparency = 0
	txt.Font = Enum.Font.GothamBlack
	txt.TextScaled = true
	txt.Parent = gui

	TweenService:Create(txt, TweenInfo.new(1.0), {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	}):Play()
	
	TweenService:Create(gui, TweenInfo.new(1.0), {
		StudsOffset = Vector3.new(0, 6, 0)
	}):Play()

	Debris:AddItem(gui, 1.1)
end

return CanVFX
