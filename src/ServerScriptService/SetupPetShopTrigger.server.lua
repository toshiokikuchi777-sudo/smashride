-- ServerScriptService/SetupPetShopTrigger.server.lua
-- workspace.shop.petShop に Trigger + ProximityPrompt を自動生成（冪等）

local Workspace = game:GetService("Workspace")

local SHOP_PATH = {"shop", "petShop"} -- workspace.shop.petShop
local TRIGGER_NAME = "Trigger"

-- Triggerの見た目・判定サイズ（入口を覆うサイズに調整してOK）
local TRIGGER_SIZE = Vector3.new(12, 8, 12)
local TRIGGER_TRANSPARENCY = 1
local TRIGGER_CAN_COLLIDE = false

-- ProximityPrompt設定
local PROMPT_ACTION_TEXT = "OPEN"
local PROMPT_OBJECT_TEXT = "PET GACHA"
local PROMPT_HOLD_DURATION = 0
local PROMPT_MAX_DISTANCE = 20  -- 遠くから反応するように距離を拡大
local PROMPT_KEY = Enum.KeyCode.E

local function findPath(root: Instance, path: {string})
	local current = root
	for _, name in ipairs(path) do
		current = current:FindFirstChild(name)
		if not current then return nil end
	end
	return current
end

local function getModelPivotCFrame(model: Instance): CFrame?
	-- ModelにもFolderにも対応（Folderの場合はPrimaryPartがないので、BasePartを探す）
	if model:IsA("Model") then
		local ok, cf = pcall(function()
			return model:GetPivot()
		end)
		if ok then return cf end
	end

	-- Folder/Modelどちらでも最初のBasePart位置を基準にする
	local base = model:FindFirstChildWhichIsA("BasePart", true)
	if base then
		return base.CFrame
	end

	return nil
end

local function ensureTrigger(petShop: Instance)
	-- 既にTriggerがあるなら、それを優先
	local trigger = petShop:FindFirstChild(TRIGGER_NAME, true)
	if trigger and trigger:IsA("BasePart") then
		-- Promptだけ無いケースに備える
		local prompt = trigger:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = PROMPT_ACTION_TEXT
			prompt.ObjectText = PROMPT_OBJECT_TEXT
			prompt.HoldDuration = PROMPT_HOLD_DURATION
			prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
			prompt.KeyboardKeyCode = PROMPT_KEY
			prompt.RequiresLineOfSight = false
			prompt.Parent = trigger
			-- print("[SetupPetShopTrigger] ProximityPrompt created on existing Trigger")
		else
			-- print("[SetupPetShopTrigger] Trigger & ProximityPrompt already exist")
		end
		return
	end

	-- Triggerが無いなら新規作成（petShop直下に置く）
	local pivot = getModelPivotCFrame(petShop)
	if not pivot then
		warn("[SetupPetShopTrigger] petShop pivot not found. Put any BasePart inside petShop.")
		return
	end

	-- 入口前に置きたい場合：ここでオフセット調整（Z方向に前へ）
	-- 例：pivot * CFrame.new(0, 0, -8) など。まずは中心に置いてOK。
	local triggerCF = pivot * CFrame.new(0, 0, 0)

	trigger = Instance.new("Part")
	trigger.Name = TRIGGER_NAME
	trigger.Size = TRIGGER_SIZE
	trigger.Anchored = true
	trigger.CanCollide = TRIGGER_CAN_COLLIDE
	trigger.Transparency = TRIGGER_TRANSPARENCY
	trigger.CFrame = triggerCF
	trigger.Parent = petShop

	-- Prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = PROMPT_OBJECT_TEXT
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.KeyboardKeyCode = PROMPT_KEY
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger

	-- print("[SetupPetShopTrigger] Trigger & ProximityPrompt created at petShop pivot")
end

-- 実行
local petShop = findPath(Workspace, SHOP_PATH)
if not petShop then
	warn("[SetupPetShopTrigger] workspace.shop.petShop not found. Check hierarchy/path.")
	return
end

ensureTrigger(petShop)
