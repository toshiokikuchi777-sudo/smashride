-- ReplicatedStorage/Client/VFX/MoneyVFX.lua
local MoneyVFX = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local COLORS = {
	COMMON = Color3.fromRGB(255, 255, 255),
	RARE = Color3.fromRGB(85, 170, 255),
	EPIC = Color3.fromRGB(170, 85, 255),
	LEGENDARY = Color3.fromRGB(255, 170, 0)
}

function MoneyVFX.PlayPop(position, amount, rarity)
	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromScale(4, 1.5)
	bg.StudsOffset = Vector3.new(0, 2, 0)
	bg.Parent = workspace
	
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Position = position
	part.Parent = workspace
	bg.Adornee = part
	Debris:AddItem(part, 2)

	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Text = "+" .. tostring(amount)
	txt.TextColor3 = COLORS[rarity] or Color3.new(1,1,1)
	txt.Font = Enum.Font.FredokaOne
	txt.TextScaled = true
	txt.Parent = bg

	TweenService:Create(bg, TweenInfo.new(1, Enum.EasingStyle.Quart), {StudsOffset = Vector3.new(0, 5, 0)}):Play()
	TweenService:Create(txt, TweenInfo.new(1), {TextTransparency = 1}):Play()
	Debris:AddItem(bg, 1.1)
end

local COIN_SOUND_ID = "rbxassetid://99023919906775"
local lastSoundTime = 0
local SOUND_COOLDOWN = 0.08 -- 音が重なりすぎないように制限

-- コイン収集エフェクト (CanControllerから呼ばれる)
function MoneyVFX.PlayCollectionEffect(position)
	if not position then return end
	
	-- 効果音の再生 (クールダウン制御)
	local now = tick()
	if now - lastSoundTime > SOUND_COOLDOWN then
		lastSoundTime = now
		local sound = Instance.new("Sound")
		sound.SoundId = COIN_SOUND_ID
		sound.Volume = 0.45
		sound.Pitch = 1.0 + (math.random(-10, 10) / 100) -- 少しピッチを揺らして自然に
		sound.Parent = workspace
		sound:Play()
		Debris:AddItem(sound, 1.5)
	end

	-- 簡易的なビジュアル演出 (小さな閃光)
	local p = Instance.new("Part")
	p.Size = Vector3.new(1.5, 1.5, 1.5)
	p.Transparency = 0.4
	p.Color = Color3.fromRGB(255, 255, 100)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.Position = position
	p.Shape = Enum.PartType.Ball
	p.Parent = workspace
	
	TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {
		Size = Vector3.new(4, 4, 4),
		Transparency = 1
	}):Play()
	Debris:AddItem(p, 0.5)
end

return MoneyVFX
