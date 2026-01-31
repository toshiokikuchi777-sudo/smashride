-- Client/Animation/HammerAnimator.lua
-- 叩きアニメの安定化専用（Respawn/遅延/Track死に対応）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local HammerAnimator = {}

local character : Model? = nil
local humanoid : Humanoid? = nil
local animator : Animator? = nil

local hammerModel : Instance? = nil
local hammerHandle : BasePart? = nil
local hammerMotor : Motor6D? = nil

local hitTrack : AnimationTrack? = nil
local conns = {}

local function disconnectAll()
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(conns)
end

local function getHitAnim()
	local folder = ReplicatedStorage:FindFirstChild("Animations")
	return folder and folder:FindFirstChild("HammerHit")
end

local function ensureTrack()
	if not animator then return nil end
	if hitTrack and hitTrack.Parent == animator then return hitTrack end
	
	local anim = getHitAnim()
	if not anim then return nil end
	
	hitTrack = animator:LoadAnimation(anim)
	hitTrack.Priority = Enum.AnimationPriority.Action
	return hitTrack
end

local function refreshHammerRefs()
	if not character then return end
	
	local visual = character:FindFirstChild("HammerVisual", true)
	if visual then
		hammerModel = visual
		hammerHandle = visual:FindFirstChild("Handle")
		hammerMotor = visual:FindFirstChild("HammerMotor", true)
	end
end

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")

	refreshHammerRefs()

	table.insert(conns, char.ChildAdded:Connect(function(c)
		if c.Name == "HammerVisual" then
			task.defer(refreshHammerRefs)
		end
	end))

	table.insert(conns, char.DescendantAdded:Connect(function(d)
		if d.Name == "HammerMotor" then
			task.defer(refreshHammerRefs)
		end
	end))
end

function HammerAnimator.Init()
	disconnectAll()

	if player.Character then
		setupCharacter(player.Character)
	end

	table.insert(conns, player.CharacterAdded:Connect(function(char)
		hitTrack = nil
		hammerModel = nil
		hammerHandle = nil
		hammerMotor = nil
		setupCharacter(char)
	end))
end

function HammerAnimator.GetHandle()
	refreshHammerRefs()
	return hammerHandle
end

function HammerAnimator.Swing()
	if not character or not humanoid then return end
	
	-- ハンマーが装備されていない場合は無視
	local hammerType = player:GetAttribute("EquippedHammer")
	if not hammerType or hammerType == "NONE" then return end

	-- 1) Asset animation
	local track = ensureTrack()
	if track then
		pcall(function()
			if track.IsPlaying then track:Stop() end
			track:Play(0.1, 1, 1.5)
		end)
	end

	-- 2) Procedural (Enhanced)
	refreshHammerRefs()
	if hammerMotor and not character:GetAttribute("IsSwinging") then
		character:SetAttribute("IsSwinging", true)
		local orig = hammerMotor.C0
		
		-- よりダイナミックに: 角度を深くし(-115度)、少し前方に突き出す
		local swingGoal = orig * CFrame.new(0, 0, -1.0) * CFrame.Angles(math.rad(-115), 0, 0)
		
		-- 振り下ろし (Snap!)
		TweenService:Create(hammerMotor, TweenInfo.new(0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			C0 = swingGoal
		}):Play()
		
		-- ため & 戻り
		task.delay(0.12, function()
			if hammerMotor then
				TweenService:Create(hammerMotor, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { C0 = orig }):Play()
			end
			task.delay(0.3, function()
				if character then character:SetAttribute("IsSwinging", false) end
			end)
		end)
	end
end

return HammerAnimator
