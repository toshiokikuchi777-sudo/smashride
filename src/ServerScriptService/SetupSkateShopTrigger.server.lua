-- ServerScriptService/SetupSkateShopTrigger.server.lua
-- workspace.shop.skateshop に Trigger + ProximityPrompt を自動生成（冪等）

local Workspace = game:GetService("Workspace")

local SHOP_PATH = {"shop", "skateshop"} -- workspace.shop.skateshop
local TRIGGER_NAME = "Trigger"

-- Triggerの見た目・判定サイズ（入口を覆うサイズに調整してOK）
local TRIGGER_SIZE = Vector3.new(12, 8, 12)
local TRIGGER_TRANSPARENCY = 1
local TRIGGER_CAN_COLLIDE = false

-- ProximityPrompt設定
local PROMPT_ACTION_TEXT = "OPEN"
local PROMPT_OBJECT_TEXT = "SKATE SHOP"
local PROMPT_HOLD_DURATION = 0
local PROMPT_MAX_DISTANCE = 10
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

local function ensureTrigger(skateshop: Instance)
	-- 既にTriggerがあるなら、それを優先
	local trigger = skateshop:FindFirstChild(TRIGGER_NAME, true)
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
			print("[SetupSkateShopTrigger] ProximityPrompt created on existing Trigger")
		else
			print("[SetupSkateShopTrigger] Trigger & ProximityPrompt already exist")
		end
		return
	end

	-- Triggerが無いなら新規作成（skateshop直下に置く）
	local pivot = getModelPivotCFrame(skateshop)
	if not pivot then
		warn("[SetupSkateShopTrigger] skateshop pivot not found. Put any BasePart inside skateshop.")
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
	trigger.Parent = skateshop

	-- Prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = PROMPT_OBJECT_TEXT
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.KeyboardKeyCode = PROMPT_KEY
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger

	print("[SetupSkateShopTrigger] Trigger & ProximityPrompt created at skateshop pivot")
end

-- 実行
local skateshop = findPath(Workspace, SHOP_PATH)
if not skateshop then
	warn("[SetupSkateShopTrigger] workspace.shop.skateshop not found. Check hierarchy/path.")
	return
end

ensureTrigger(skateshop)
