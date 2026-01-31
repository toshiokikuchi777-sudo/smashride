-- MoneyDrop.lua
-- 3Dお金アイテムのスポーンと取得処理

local MoneyDrop = {}

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Config.Constants)
-- local CanService = require(game:GetService("ServerScriptService").Services.CanService)
-- テンプレートは関数内で取得

-- モジュール初期化
function MoneyDrop.Init()
	print("[MoneyDrop] 初期化完了")
end

-- お金をスポーンさせる
function MoneyDrop.SpawnMoney(position, totalReward, count, scale)
	local templates = ServerStorage:FindFirstChild("Templates")
	local moneyFolder = templates and templates:FindFirstChild("Money")
	local moneyTemplate = moneyFolder and moneyFolder:FindFirstChild("GoldCoin")
	
	if not moneyTemplate then
		warn("[MoneyDrop] Money template not found in ServerStorage")
		return
	end
	scale = scale or 2.0
	count = count or 3
	local rewardPerCoin = math.floor(totalReward / count)
	if rewardPerCoin <= 0 then rewardPerCoin = 1 end
	
	local dropFolder = workspace:FindFirstChild("DroppedItems")
	if not dropFolder then
		dropFolder = Instance.new("Folder")
		dropFolder.Name = "DroppedItems"
		dropFolder.Parent = workspace
	end

	for i = 1, count do
		local coin = moneyTemplate:Clone()
		coin.Name = "DroppedMoney"
		
		-- 【重要】クローン直後にDebrisに登録。これにより、以降のロジックでエラーが起きても確実に消える。
		Debris:AddItem(coin, 6)
		
		-- モデルを大きくする
		if coin:IsA("Model") then
			coin:ScaleTo(scale)
		end
		
		-- ランダムな速度で弾け飛ばす
		local angle = math.rad(math.random(0, 360))
		local force = math.random(15, 35)
		local velocity = Vector3.new(
			math.cos(angle) * force,
			math.random(40, 70),
			math.sin(angle) * force
		)
		
		-- 初期位置の微調整
		local offset = Vector3.new(math.random(-3, 3), math.random(1, 4), math.random(-3, 3))
		local targetPos = position + offset

		if coin:IsA("Model") then
			coin:PivotTo(CFrame.new(targetPos))
		else
			coin.CFrame = CFrame.new(targetPos)
		end
		
		-- 属性の付与
		coin:SetAttribute("RewardValue", rewardPerCoin)
		coin.Parent = dropFolder
		
		-- 当たり判定の集約
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Shape = Enum.PartType.Ball
		hitbox.Size = Vector3.new(4, 4, 4)
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.CanTouch = true
		hitbox.Position = targetPos
		hitbox.Parent = coin
		
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hitbox
		local root = coin:IsA("BasePart") and coin or coin:FindFirstChildWhichIsA("BasePart", true)
		if root then
			root.AssemblyLinearVelocity = velocity -- randomDir は velocity に変更
			root.CanCollide = false -- 衝突無効
			root.CanTouch = false   -- 触れないように
			root.Anchored = false
		end
		weld.Part1 = coin.PrimaryPart or coin:FindFirstChildWhichIsA("BasePart", true)
		weld.Parent = hitbox

		-- 取得イベント
		local claimed = false
		local function onTouched(hit)
			if claimed then return end
			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				claimed = true
				MoneyDrop.ClaimMoney(player, coin)
			end
		end
		
		hitbox.Touched:Connect(onTouched)
		
		-- モデル内の全パーツの CanTouch をオフにして物理負荷を軽減
		for _, part in ipairs(coin:GetDescendants()) do
			if part:IsA("BasePart") and part ~= hitbox then
				part.CanTouch = false
				part.AssemblyAngularVelocity = Vector3.new(math.random(-5,5), math.random(-5,5), math.random(-5,5))
			end
		end
		
		-- 速度の適用
		hitbox.AssemblyLinearVelocity = velocity
	end
end

-- お金を取得した時の処理
function MoneyDrop.ClaimMoney(player, coinInstance)
	local CanService = require(game:GetService("ServerScriptService").Services.CanService) -- 遅延読み込み
	local rewardValue = coinInstance:GetAttribute("RewardValue") or 0
	local pos = (coinInstance:IsA("Model") and coinInstance:GetPivot().Position) or (coinInstance:IsA("BasePart") and coinInstance.Position) or player.Character:GetPivot().Position
	print(string.format("[MoneyDrop] 🔍 pos calculated: %.1f,%.1f,%.1f", pos.X, pos.Y, pos.Z))

	print(string.format("[MoneyDrop] Claimed: %s collected %d score", player.Name, rewardValue))
	
	-- スコア加算 (pcallで保護し、失敗してもDestroyを妨げないようにする)
	local success, err = pcall(function()
		CanService.AddScore(player, rewardValue)
	end)
	
	if not success then
		warn("[MoneyDrop] AddScore failed:", err)
	end
	
	-- クライアントへ演出通知（音とエフェクト）
	Net.E(Constants.Events.MoneyCollected):FireClient(player, pos, rewardValue)
	print(string.format("[MoneyDrop] 🔊 Sent MoneyCollected to %s at %.1f,%.1f,%.1f with value %d", player.Name, pos.X, pos.Y, pos.Z, rewardValue))
	
	-- 確実に消去
	if coinInstance and coinInstance.Parent then
		coinInstance:Destroy()
		print(string.format("[MoneyDrop] 🗑️ Destroyed coin for %s", player.Name))
	else
		warn(string.format("[MoneyDrop] ⚠️ Coin already destroyed or has no parent for %s", player.Name))
	end
end

-- 視覚効果専用のお金スポーン（タッチ判定なし）
function MoneyDrop.SpawnVisualMoney(position, count, scale)
	local templates = ServerStorage:FindFirstChild("Templates")
	local moneyFolder = templates and templates:FindFirstChild("Money")
	local moneyTemplate = moneyFolder and moneyFolder:FindFirstChild("GoldCoin")
	
	if not moneyTemplate then return end
	count = count or 3
	
	local dropFolder = workspace:FindFirstChild("DroppedItems")
	if not dropFolder then
		dropFolder = Instance.new("Folder")
		dropFolder.Name = "DroppedItems"
		dropFolder.Parent = workspace
	end

	for i = 1, count do
		local coin = moneyTemplate:Clone()
		coin.Name = "VisualMoney"
		
		-- 3秒後に自動消滅
		Debris:AddItem(coin, 3)
		
		-- モデルを大きくする
		if coin:IsA("Model") then
			coin:ScaleTo(scale or 2.0)
		end
		
		-- ランダムな速度で弾け飛ばす
		local angle = math.rad(math.random(0, 360))
		local force = math.random(15, 35)
		local velocity = Vector3.new(
			math.cos(angle) * force,
			math.random(40, 70),
			math.sin(angle) * force
		)
		
		-- 初期位置の微調整
		local offset = Vector3.new(math.random(-3, 3), math.random(1, 4), math.random(-3, 3))
		local targetPos = position + offset

		if coin:IsA("Model") then
			coin:PivotTo(CFrame.new(targetPos))
		else
			coin.CFrame = CFrame.new(targetPos)
		end
		
		coin.Parent = dropFolder
		
		-- モデル内の全パーツにCanTouch = falseを設定（タッチ判定を完全に無効化）
		for _, part in ipairs(coin:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanTouch = false
				part.CanCollide = false -- 物理衝突を無効化
				part.AssemblyAngularVelocity = Vector3.new(math.random(-5,5), math.random(-5,5), math.random(-5,5))
				part.AssemblyLinearVelocity = velocity
			end
		end
	end
	
	print(string.format("[MoneyDrop] 視覚効果コイン %d個 をスポーン", count))
end

return MoneyDrop
