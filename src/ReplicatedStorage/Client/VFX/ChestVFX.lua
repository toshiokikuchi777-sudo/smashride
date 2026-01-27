-- ChestVFX.lua
-- 宝箱のVFX演出(spawn/claimed/despawn)

local ChestVFX = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ChestConfig = require(ReplicatedStorage.Shared.Config.ChestConfig)

-- アクティブなVFX
local activeVFX = {} -- { [chestId] = { particles, beams, etc } }

-- 宝箱モデルをAttributeで検索
local function getChestModelById(chestId)
	if not workspace:FindFirstChild("Chests") then return nil end
	for _, child in ipairs(workspace.Chests:GetChildren()) do
		if child:GetAttribute("ChestId") == chestId then
			return child
		end
	end
	return nil
end

-- スポーン演出
function ChestVFX.PlaySpawnEffect(chestId, chestType, position)
	print("[ChestVFX] スポーン演出:", chestType, chestId)
	
	local chestData = ChestConfig.ChestTypes[chestType]
	
	-- 宝箱モデルを取得 (属性で検索)
	local chestModel = getChestModelById(chestId)
	
	-- クライアントへの複製待ち
	if not chestModel then
		local startTime = os.clock()
		while not chestModel and os.clock() - startTime < 3 do
			task.wait(0.1)
			chestModel = getChestModelById(chestId)
		end
	end
	
	if not chestModel then
		-- イベント終了直後などは消えている可能性があるため、warnではなく確認ログにとどめる
		-- print("[ChestVFX] 宝箱が見つかりません(消滅済み):", chestId)
		return
	end
	
	-- 降下アニメーション
	if chestModel then
		-- 初期位置(高い位置)
		local groundCFrame = CFrame.new(position)
		local startCFrame = groundCFrame * CFrame.new(0, ChestConfig.SpawnHeight, 0)
		chestModel:PivotTo(startCFrame)
		
		-- Tween用のCFrameValueを作成
		local cfValue = Instance.new("CFrameValue")
		cfValue.Value = startCFrame
		
		cfValue.Changed:Connect(function(newCF)
			if chestModel and chestModel.Parent then
				chestModel:PivotTo(newCF)
			end
		end)
		
		-- 降下Tween
		local tween = TweenService:Create(cfValue, TweenInfo.new(1.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			Value = groundCFrame
		})
		
		tween:Play()
		
		-- 完了後にValueを削除し、衝突を有効化
		tween.Completed:Connect(function()
			cfValue:Destroy()
			if chestModel then
				for _, part in ipairs(chestModel:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = true
					end
				end
			end
		end)
		
		-- 安全策: 2秒後に強制的に衝突を有効化
		task.delay(2, function()
			if chestModel then
				for _, part in ipairs(chestModel:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = true
					end
				end
			end
		end)
	end
	
	-- 着地リング(パーティクル)
	task.delay(1.5, function()
		ChestVFX.CreateLandingRing(position, chestData.color)
	end)
end

-- 着地リング
function ChestVFX.CreateLandingRing(position, color)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 0.1, 1)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = workspace
	
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	
	-- リング状のパーティクル
	local particle = Instance.new("ParticleEmitter")
	particle.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particle.Color = ColorSequence.new(color)
	particle.Size = NumberSequence.new(2)
	particle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	particle.Lifetime = NumberRange.new(0.5, 1)
	particle.Rate = 100
	particle.Speed = NumberRange.new(10, 15)
	particle.SpreadAngle = Vector2.new(0, 0)
	particle.Enabled = true
	particle.Parent = attachment
	
	-- 1秒後に削除
	task.delay(1, function()
		particle.Enabled = false
		Debris:AddItem(part, 2)
	end)
end

-- Claim演出
function ChestVFX.PlayClaimEffect(chestId, chestType, claimerName, centerPos, rewards)
	print("[ChestVFX] Claim演出(破砕):", claimerName, chestType)
	
	local chestData = ChestConfig.ChestTypes[chestType]
	local chestModel = getChestModelById(chestId)
	
	-- 爆発的なバースト
	ChestVFX.CreateClaimBurst(centerPos, chestData.color)
	
	-- 宝箱がその場でバラバラになるような演出（モデルがあれば）
	if chestModel then
		for _, part in ipairs(chestModel:GetDescendants()) do
			if part:IsA("BasePart") then
				-- 小さくなって消えるアニメーション
				local tween = TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Size = Vector3.new(0, 0, 0),
					Transparency = 1
				})
				tween:Play()
			end
		end
		
		-- 破片をいくつか飛ばす
		for i = 1, 5 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.5, 0.5, 0.5)
			p.Color = chestData.color
			p.Material = Enum.Material.Neon
			p.Position = centerPos
			p.CanCollide = false
			p.Parent = workspace
			
			local vel = Vector3.new(math.random(-20, 20), math.random(20, 40), math.random(-20, 20))
			p.AssemblyLinearVelocity = vel
			Debris:AddItem(p, 0.5)
		end
	end
end

-- Claim時の光球バースト
function ChestVFX.CreateClaimBurst(position, color)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = workspace
	
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	
	-- バーストパーティクル
	local particle = Instance.new("ParticleEmitter")
	particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particle.Color = ColorSequence.new(color)
	particle.Size = NumberSequence.new(1)
	particle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	particle.Lifetime = NumberRange.new(1, 2)
	particle.Rate = 200
	particle.Speed = NumberRange.new(20, 30)
	particle.SpreadAngle = Vector2.new(180, 180)
	particle.Enabled = true
	particle.Parent = attachment
	
	-- 0.3秒後に停止
	task.delay(0.3, function()
		particle.Enabled = false
		Debris:AddItem(part, 3)
	end)
end

-- Despawn演出
function ChestVFX.PlayDespawnEffect(chestId, reason)
	print("[ChestVFX] Despawn演出:", chestId, reason)
	
	-- 宝箱モデルを取得 (属性で検索)
	local chestModel = getChestModelById(chestId)
	
	if not chestModel then
		return
	end
	
	-- フェードアウト
	for _, part in ipairs(chestModel:GetDescendants()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, TweenInfo.new(0.5), {Transparency = 1})
			tween:Play()
		end
	end
end

return ChestVFX
