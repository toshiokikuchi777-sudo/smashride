-- StarterPlayer/StarterPlayerScripts/Controllers/GrindController.lua
-- レールグラインドのクライアント側処理（演出・エフェクト）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GrindController = {}

-- 設定読み込み
local GrindConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GrindConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local player = Players.LocalPlayer

-- グラインド状態
local isGrinding = false
local currentRail = nil
local grindSound = nil
local sparkEffect = nil
local grindAnimation = nil
local grindAnimTrack = nil

-- 火花エフェクトを作成
local function createSparkEffect()
	local effect = Instance.new("ParticleEmitter")
	effect.Name = "GrindSparks"

	-- 火花の見た目
	effect.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	effect.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 50))
	})

	-- パーティクルの動き
	effect.Lifetime = NumberRange.new(0.2, 0.4)
	effect.Rate = 50
	effect.Speed = NumberRange.new(5, 15)
	effect.SpreadAngle = Vector2.new(30, 30)
	effect.Acceleration = Vector3.new(0, -20, 0) -- 重力

	-- サイズと透明度
	effect.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.1)
	})
	effect.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})

	effect.LightEmission = 1
	effect.LightInfluence = 0

	effect.Enabled = false

	return effect
end

-- グラインド音を作成
local function createGrindSound()
	local sound = Instance.new("Sound")
	sound.Name = "GrindSound"
	sound.SoundId = GrindConfig.GrindSoundId
	sound.Volume = 0.5
	sound.PlaybackSpeed = 1.2 -- スケボー走行音のピッチに合わせる
	sound.Looped = true
	sound.RollOffMaxDistance = 50
	sound.RollOffMinDistance = 10

	return sound
end

-- グラインドアニメーションをロード（将来的に追加可能）
local function loadGrindAnimation()
	-- TODO: グラインド専用アニメーションを追加する場合はここで設定
	-- 現在はスケートボードの Coasting アニメーションを流用
	return nil
end

-- グラインド開始時の処理
local function onGrindStarted(rail)
	if isGrinding then return end

	print("[GrindController] Grind started")
	isGrinding = true
	currentRail = rail

	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- 火花エフェクトを作成・配置
	if GrindConfig.SparkEffectEnabled then
		if not sparkEffect then
			sparkEffect = createSparkEffect()
		end
		sparkEffect.Parent = rootPart
		sparkEffect.Enabled = true
	end

	-- グラインド音を再生
	if GrindConfig.GrindSoundEnabled then
		if not grindSound then
			grindSound = createGrindSound()
		end
		grindSound.Parent = rootPart
		grindSound:Play()
	end

	-- グラインドアニメーション再生（将来的に追加）
	-- if grindAnimation and not grindAnimTrack then
	-- 	local humanoid = character:FindFirstChild("Humanoid")
	-- 	if humanoid then
	-- 		local animator = humanoid:FindFirstChildOfClass("Animator")
	-- 		if animator then
	-- 			grindAnimTrack = animator:LoadAnimation(grindAnimation)
	-- 			grindAnimTrack:Play()
	-- 		end
	-- 	end
	-- end
end

-- グラインド終了時の処理
local function onGrindEnded(exitVelocity, shouldJump)
	if not isGrinding then return end

	print("[GrindController] Grind ended")
	isGrinding = false
	currentRail = nil

	-- 自身のジャンプ処理（サーバーからの情報を優先適用）
	local character = player.Character
	if character and shouldJump then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")
		if rootPart and exitVelocity then
			print("[GrindController] Applying client-side jump velocity")
			rootPart.AssemblyLinearVelocity = exitVelocity
		end
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end

	-- 火花エフェクトを停止
	if sparkEffect then
		sparkEffect.Enabled = false
	end
-- ... (rest of the code for cleanup)

	-- グラインド音を停止
	if grindSound then
		grindSound:Stop()
	end

	-- グラインドアニメーション停止
	if grindAnimTrack then
		grindAnimTrack:Stop()
		grindAnimTrack = nil
	end
end

-- IsGrinding 属性の変化を監視
local function watchGrindingAttribute()
	-- 曲線グラインドのセグメント移行で誤作動するため無効化
	-- 属性による自動終了は行わず、OnClientEvent の通知のみを信頼する
end

-- キャラクター変更時のクリーンアップ
local function onCharacterAdded(character)
	-- 古いエフェクトをクリーンアップ
	if sparkEffect then
		sparkEffect:Destroy()
		sparkEffect = nil
	end
	if grindSound then
		grindSound:Destroy()
		grindSound = nil
	end
	if grindAnimTrack then
		grindAnimTrack:Stop()
		grindAnimTrack = nil
	end

	isGrinding = false
	currentRail = nil

	-- 新しいキャラクターで属性監視を再設定
	watchGrindingAttribute()
end

function GrindController.Init()
	print("[GrindController] Init")

	-- グラインド開始イベント
	local GrindStarted = Net.E(Constants.Events.GrindStarted)
	if GrindStarted then
		GrindStarted.OnClientEvent:Connect(function(rail)
			onGrindStarted(rail)
		end)
	end

	-- グラインド終了イベント
	local GrindEnded = Net.E(Constants.Events.GrindEnded)
	if GrindEnded then
		GrindEnded.OnClientEvent:Connect(function(exitVelocity, shouldJump)
			onGrindEnded(exitVelocity, shouldJump)
		end)
	end

	-- 属性監視
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- グラインドアニメーションをロード（将来的に追加）
	grindAnimation = loadGrindAnimation()
end

return GrindController
