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
		
		local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
		local tween = TweenService:Create(cfValue, tweenInfo, {Value = groundCFrame})
		tween:Play()
		
		tween.Completed:Connect(function()
			cfValue:Destroy()
			
			-- 着地エフェクト
			if chestModel and chestModel.Parent then
				-- Play landing effect (shake, dust etc)
			end
		end)
	end
end

-- 宝箱取得演出 (ChestControllerから呼ばれる)
function ChestVFX.PlayClaimEffect(chestId, chestType, claimerName, centerPos, rewards)
	print("[ChestVFX] Claim演出:", chestId, chestType, claimerName)
	
	-- 既存のPlayClaimedEffectを呼び出す
	if centerPos then
		ChestVFX.PlayClaimedEffect(chestId, centerPos)
	end
	
	-- TODO: 報酬UI表示はChestEventUIで行う
end

-- 獲得演出
function ChestVFX.PlayClaimedEffect(chestId, position)
	print("[ChestVFX] 獲得演出:", chestId)
end

-- デスポーン/キャンセル演出
function ChestVFX.PlayDespawnEffect(chestId)
	print("[ChestVFX] デスポーン演出:", chestId)
end

return ChestVFX
