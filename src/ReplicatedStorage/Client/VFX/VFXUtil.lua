-- ReplicatedStorage/Client/VFX/VFXUtil.lua
-- VFX関連の共通ユーティリティ

local VFXUtil = {}

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- ネオンパーツ（演出用）を生成
function VFXUtil.createNeonPart(size, cframe, color, shape)
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

-- Tweenで消滅させる
function VFXUtil.tweenOut(inst, tweenInfo, props)
	local tw = TweenService:Create(inst, tweenInfo, props)
	tw:Play()
	Debris:AddItem(inst, tweenInfo.Time + 0.1)
end

return VFXUtil
