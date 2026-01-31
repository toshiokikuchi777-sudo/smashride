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
			prompt.Parent = trigger
		end
		return trigger
	end

	-- 新規作成
	local cf = getModelPivotCFrame(skateshop)
	if not cf then return nil end

	local part = Instance.new("Part")
	part.Name = TRIGGER_NAME
	part.Size = TRIGGER_SIZE
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = TRIGGER_CAN_COLLIDE
	part.Transparency = TRIGGER_TRANSPARENCY
	part.Parent = skateshop

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = PROMPT_OBJECT_TEXT
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.KeyboardKeyCode = PROMPT_KEY
	prompt.Parent = part

	return part
end

local function init()
	local skateshop = findPath(Workspace, SHOP_PATH)
	if not skateshop then
		warn("[SetupSkateShopTrigger] Target not found:", table.concat(SHOP_PATH, "."))
		return
	end

	local trigger = ensureTrigger(skateshop)
	if trigger then
		-- print("[SetupSkateShopTrigger] Trigger & ProximityPrompt created at skateshop pivot")
	else
		warn("[SetupSkateShopTrigger] Failed to create trigger (no basepart/pivot found)")
	end
end

init()
