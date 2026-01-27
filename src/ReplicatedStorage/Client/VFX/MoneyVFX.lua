-- MoneyVFX.lua
-- お金・報酬関連のVFX演出（独立版）

local MoneyVFX = {}

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local COIN_COLLECT_SOUND_ID = "rbxassetid://1210852193" -- コイン取得音

-- 内部ユーティリティ（CanVFXのものと重複するが、疎結合を優先）
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
	p.Shape = shape or Enum.PartType.Ball
	p.Parent = workspace
	return p
end

local function tweenOut(inst, tweenInfo, props)
	local tw = TweenService:Create(inst, tweenInfo, props)
	tw:Play()
	Debris:AddItem(inst, tweenInfo.Time + 0.1)
end

-- コイン取得時のエフェクトとサウンド
function MoneyVFX.PlayCollectionEffect(worldPos)
	if not worldPos then return end

	-- 1. サウンド再生
	local sound = Instance.new("Sound")
	sound.SoundId = COIN_COLLECT_SOUND_ID
	sound.Volume = 0.6
	sound.Parent = workspace
	
	-- サウンド再生を非同期で実行（ロードを待たずにUI等を進める）
	task.spawn(function()
		if not sound.IsLoaded then
			sound.Loaded:Wait()
		end
		sound:Play()
		sound.Ended:Wait()
		sound:Destroy()
	end)
	
	-- 念のため最大2秒後に削除
	Debris:AddItem(sound, 2)

	-- 2. 視覚演出（光のポップ）
	local flash = createNeonPart(
		Vector3.new(0.5, 0.5, 0.5), 
		CFrame.new(worldPos), 
		Color3.new(1, 1, 0.8), 
		Enum.PartType.Ball
	)
	flash.Transparency = 0.2
	
	tweenOut(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(4, 4, 4),
		Transparency = 1
	})
end

return MoneyVFX
