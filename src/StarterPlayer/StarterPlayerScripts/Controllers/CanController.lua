--// CanController.lua
--// ロジック拠点：判定、サーバー通信、アニメーションのトリガー
--// TS: 21:35 (Production Cleanup - HammerAnimator Integrated)
--// [PATCH] RemoteEvent定義の漏れ防止 + CanCrushResult(model=nil)対応 + pendingの詰まり防止

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local player = Players.LocalPlayer
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local CanVFX = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("VFX"):WaitForChild("CanVFX"))
local MoneyVFX = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("VFX"):WaitForChild("MoneyVFX"))
local HammerAnimator = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Animation"):WaitForChild("HammerAnimator"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local FaceTargetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("FaceTargetConfig"))
local FaceTargetUI = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("FaceTargetUI"))
local RewardUI = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("RewardUI"))
local FaceTargetSummaryUI = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("FaceTargetSummaryUI"))

-- ✅ 必須RemoteEvent（このファイル内で確実に定義）
local CrushCanVisual   = Net.E("CrushCanVisual")
local ShockwaveVFX     = Net.E("ShockwaveVFX")
local MultiplierVFX    = Net.E("MultiplierVFX")
local CanCrushResult   = Net.E("CanCrushResult")
local RE_CanLocked     = Net.E("CanLocked")

local CanController = {}
local lastClickTime = 0

-- HIT_CACHE_SESSION[model] = { state="pending"/"confirmed", t=tick() }
local HIT_CACHE_SESSION = setmetatable({}, { __mode = "k" })

-- =========================
-- ヒット判定核心
-- =========================

local function flattenCan(model)
	if not model or not model.Parent or model:GetAttribute("IsFlattened") then return end
	model:SetAttribute("IsFlattened", true)

	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false

			local mesh = child:FindFirstChildWhichIsA("SpecialMesh")
			local size = child.Size
			local targetSize = Vector3.new(size.X * 1.2, 0.001, size.Z * 1.2)

			local currentCF = child.CFrame
			local bottomY = currentCF.Position.Y - (size.Y / 2)
			local targetY = bottomY + 0.05
			local targetCF = CFrame.new(currentCF.Position.X, targetY, currentCF.Position.Z) * currentCF.Rotation

			local ti = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(child, ti, {
				Size = targetSize,
				CFrame = targetCF,
				Transparency = 0.5
			}):Play()

			if mesh then
				TweenService:Create(mesh, ti, {
					Scale = Vector3.new(mesh.Scale.X * 1.2, 0.01, mesh.Scale.Z * 1.2)
				}):Play()
			end
		end
	end
end

local function getCanColor(canName)
	if not canName then return nil end
	local upper = string.upper(canName)
	if string.find(upper, "RED") then return "RED"
	elseif string.find(upper, "BLUE") then return "BLUE"
	elseif string.find(upper, "GREEN") then return "GREEN"
	elseif string.find(upper, "PURPLE") then return "PURPLE"
	elseif string.find(upper, "YELLOW") then return "YELLOW"
	end
	return nil
end

local function canSmashCan(canColor)
	local hammerType = player:GetAttribute("EquippedHammer")
	if not hammerType or hammerType == "NONE" then
		return false
	end

	local limit = GameConfig.HammerCanLimit[hammerType] or 0
	local index = Constants.CanColorIndex[canColor]
	return index and index <= limit
end

local function isCached(model)
	local cache = HIT_CACHE_SESSION[model]
	return cache ~= nil
end

local function handleCrush(model, hitPos, hitPart)
	if not model or not model.Parent or isCached(model) then return end

	local color = getCanColor(model.Name)
	if not canSmashCan(color) then
		local bp = hitPart or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if bp then
			CanVFX.PlayLockedVFX(bp.Position, model)
		end
		return
	end

	-- ✅ pending（サーバー承認待ち）
	HIT_CACHE_SESSION[model] = { state = "pending", t = tick() }

	-- サーバー通知（hitPos, hitPart を追加）
	Net.E("CanCrushed"):FireServer(model, hitPos, hitPart)
end

-- =========================
-- 入力監視（Raycast方式 - マウスカーソルベース）
-- =========================

local isPointerDown = false
local MAX_RAYCAST_DISTANCE = 500 -- 16から500に大幅延長 (カメラ距離対策)

local function raycastAtScreenPos(screenPos: Vector2)
	local camera = workspace.CurrentCamera
	if not camera then return nil end

	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local rayOrigin = ray.Origin
	local rayDirection = ray.Direction * MAX_RAYCAST_DISTANCE

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	
	local filterList = { workspace.Terrain }
	local cans = workspace:FindFirstChild("Cans")
	if cans then table.insert(filterList, cans) end
	local chests = workspace:FindFirstChild("Chests")
	if chests then table.insert(filterList, chests) end
	local faces = workspace:FindFirstChild("FaceTargets")
	if faces then table.insert(filterList, faces) end
	
	-- 念のため直接置かれているターゲットも含む
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name:find("Face") or child.Name:find("Piggy") then
			table.insert(filterList, child)
		end
	end

	raycastParams.FilterDescendantsInstances = filterList

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if raycastResult and raycastResult.Instance then
		return raycastResult.Instance, raycastResult.Position
	end
	return nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch = input.UserInputType == Enum.UserInputType.Touch
	if not (isMouse or isTouch) then return end

	local now = tick()
	if now - lastClickTime < 0.08 then return end
	lastClickTime = now

	isPointerDown = true

	-- ハンマー振り下ろし（入力瞬間が大事）
	HammerAnimator.Swing()

	local screenPos = isTouch and Vector2.new(input.Position.X, input.Position.Y)
		or UserInputService:GetMouseLocation()

	local hitInstance, hitPos = raycastAtScreenPos(screenPos)
	local hitProcessed = false

	-- A. 直接ヒット判定（狙い撃ち優先）
	if hitInstance and hitPos then
		print("[CanController] CLICK HIT:", hitInstance.Name, "at", hitPos)
		
		-- 射程チェックの前にターゲットを特定
		local targetModel = hitInstance:FindFirstAncestorWhichIsA("Model")
		local targetId = nil
		while targetModel and targetModel.Parent ~= workspace do
			targetId = targetModel:GetAttribute(FaceTargetConfig.AttrTargetId)
			if targetId then break end
			targetModel = targetModel.Parent:FindFirstAncestorWhichIsA("Model")
		end

		-- 射程チェック
		local playerPos = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local distance = playerPos and (playerPos.Position - hitPos).Magnitude or 999
		
		-- 射程設定: 属性を持つターゲット（特に対象が巨大な豚など）は35、それ以外は16
		local maxRange = targetId and 35 or 16

		if distance <= maxRange then
			-- 1. 顔/豚ターゲット (特定済みの場合)
			if targetId then
				Net.Fire("FaceTargetHit", targetId)
				print("[CanController] Direct Hit Target:", targetId)
				hitProcessed = true
			end

			-- 2. 缶
			if not hitProcessed and hitInstance:IsDescendantOf(workspace:FindFirstChild("Cans") or workspace) then
				local canModel = hitInstance:FindFirstAncestorWhichIsA("Model")
				if canModel and canModel.Parent and canModel.Parent.Name == "Cans" then
					handleCrush(canModel, hitPos, hitInstance)
					hitProcessed = true
				end
			end
		else
			-- 遠すぎるメッセージ
			if targetId then
				CanVFX.PlayReasonVFX(targetModel, "TOO FAR!", Color3.fromRGB(255, 200, 100))
			end
		end
	end

	-- B. 自動近密ヒット判定（空振り補填 / 操作性UP）
	if not hitProcessed then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local scanRadius = 13 -- 少し狭めにして「目の前」感を出す
			local searchInclude = {}
			local cansFolder = workspace:FindFirstChild("Cans")
			local faceFolder = workspace:FindFirstChild("FaceTargets")
			local chestFolder = workspace:FindFirstChild("Chests")
			if cansFolder then table.insert(searchInclude, cansFolder) end
			if faceFolder then table.insert(searchInclude, faceFolder) end
			if chestFolder then table.insert(searchInclude, chestFolder) end
			
			if #searchInclude > 0 then
				local params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = searchInclude
				
				local hits = workspace:GetPartBoundsInRadius(hrp.Position, scanRadius, params)
				local closestTarget = nil
				local minDistance = math.huge
				
				for _, hit in ipairs(hits) do
					local dist = (hrp.Position - hit.Position).Magnitude
					if dist < minDistance then
						minDistance = dist
						closestTarget = hit
					end
				end
				
				if closestTarget then
					-- 顔ターゲット判定 (属性ベース)
					local face = closestTarget:FindFirstAncestorWhichIsA("Model")
					local faceTid = nil
					while face and face.Parent ~= workspace do
						faceTid = face:GetAttribute(FaceTargetConfig.AttrTargetId)
						if faceTid then break end
						face = face.Parent:FindFirstAncestorWhichIsA("Model")
					end
					
					if faceTid then
						Net.Fire("FaceTargetHit", faceTid)
						print("[CanController] Auto Face Hit (Closest)")
					else
						-- 缶判定
						local can = closestTarget:FindFirstAncestorWhichIsA("Model")
						if can and can.Parent and can.Parent.Name == "Cans" then
							handleCrush(can, closestTarget.Position, closestTarget)
							print("[CanController] Auto Can Crush (Closest)")
						else
							-- 宝箱判定
							local ChestController = require(script.Parent.ChestController)
							local nearbyChest = ChestController.FindNearestChest(hrp.Position, scanRadius)
							if nearbyChest then
								ChestController.RequestClaim(nearbyChest.chestId)
								print("[CanController] Auto Chest Claim (Closest)")
							end
						end
					end
				end
			end
		end
	end

	-- 押しっぱなし補助（短時間）
	task.spawn(function()
		local startTime = tick()
		local cansFolder = workspace:FindFirstChild("Cans")
		if not cansFolder then return end

		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Whitelist
		params.FilterDescendantsInstances = { cansFolder }

		while isPointerDown do
			if tick() - startTime > 0.25 then break end

			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local parts = workspace:GetPartBoundsInRadius(hrp.Position, 4, params)

				local bestModel, bestPart = nil, nil
				local bestDist = math.huge

				for _, part in ipairs(parts) do
					local model = part:FindFirstAncestorWhichIsA("Model")
					if model and model:IsDescendantOf(cansFolder) and not isCached(model) then
						local d = (part.Position - hrp.Position).Magnitude
						if d < bestDist then
							bestDist = d
							bestModel = model
							bestPart = part
						end
					end
				end

				if bestModel then
					handleCrush(bestModel, bestPart.Position, bestPart)
				end
			end

			task.wait(0.05)
		end
	end)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		isPointerDown = false
	end
end)

-- =========================
-- 初期化
-- =========================

function CanController.Init()
	print("[CanController] DEBUG: Init Start")
	HammerAnimator.Init()
	print("[CanController] DEBUG: HammerAnimator Init Done")

	local function bindCan(m)
		if not m:IsA("Model") then return end
		local bp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		if bp then
			bp.Touched:Connect(function(hit)
				if hit:IsDescendantOf(player.Character) and isPointerDown then
					handleCrush(m, bp.Position, bp)
				end
			end)
		end
	end

	local cansFolder = workspace:WaitForChild("Cans", 10)
	print("[CanController] DEBUG: Cans folder wait done. Found:", cansFolder ~= nil)
	if cansFolder then
		for _, c in ipairs(cansFolder:GetChildren()) do bindCan(c) end
		cansFolder.ChildAdded:Connect(bindCan)
	end

	-- ... (既存のRemoteEvent接続ロジックを維持) ...

	-- サーバー演出同期：缶潰れ
	CrushCanVisual.OnClientEvent:Connect(function(m, p)
		if m and m.Parent then
			local b = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
			if b then
				local targetChar = (p and player and p.UserId == player.UserId) and player.Character or nil
				if targetChar then
					CanVFX.PlayCanCrushVFX(m, b.Position, targetChar)
				else
					CanVFX.PlayCanCrushVFX(m, b.Position, nil)
				end

				if p ~= player then
					CanVFX.PlayHitSound(nil, m)
				end
			end
			flattenCan(m)
		end
	end)

	-- サーバー演出同期：ショックウェーブ
	ShockwaveVFX.OnClientEvent:Connect(function(pos, rad, hType, isBig)
		print("[CanController] ShockwaveVFX Event! hType:", hType, "isBig:", isBig)
		CanVFX.PlayHammerHitVFX(hType or "SHOCKWAVE", pos, isBig ~= false)
	end)

	MultiplierVFX.OnClientEvent:Connect(function(canCol, mult)
		CanVFX.PlayMultiplierPopup(canCol, mult)
	end)

	-- ✅ CanCrushResult（判定結果）
	CanCrushResult.OnClientEvent:Connect(function(model, ok, reason)
		-- ★model=nil（SHOCKWAVE等）対応：pendingが詰まらないように解放
		if not model then
			local now = tick()
			for m, cache in pairs(HIT_CACHE_SESSION) do
				if type(cache) == "table" and cache.state == "pending" then
					-- 即全解除ではなく、少し古いpendingのみ解除（副作用低減）
					if now - (cache.t or now) > 0.6 then
						HIT_CACHE_SESSION[m] = nil
					end
				end
			end
			print("[CanController] CanCrushResult (no model):", ok, reason)
			return
		end

		if ok then
			HIT_CACHE_SESSION[model] = { state = "confirmed", t = tick() }

			local bp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if bp then
				local hType = player:GetAttribute("EquippedHammer")
				if hType and hType ~= "NONE" then
					CanVFX.PlayHammerHitVFX(hType, bp.Position, false)
					CanVFX.PlayCanCrushVFX(model, bp.Position, player.Character)
					CanVFX.PlayHitSound(HammerAnimator.GetHandle(), model)
				end
				task.spawn(function()
					flattenCan(model)
				end)
			end
		else
			print("[CanController] Server reject:", reason, "Model:", model and model.Name or "nil")

			HIT_CACHE_SESSION[model] = nil

			local color = (reason == "BURST_LIMIT") and Color3.fromRGB(255, 150, 0) or Color3.fromRGB(255, 80, 80)
			CanVFX.PlayReasonVFX(model, tostring(reason), color)
		end
	end)

	-- 壊せない缶（LOCKED）
	RE_CanLocked.OnClientEvent:Connect(function(pos, canModel)
		CanVFX.PlayLockedVFX(pos, canModel)
	end)

	-- 💰 お金取得演出
	Net.On("MoneyCollected", function(pos, amount)
		print(string.format("[CanController] 🔊 Received MoneyCollected event at %.1f,%.1f,%.1f with value %d", pos.X, pos.Y, pos.Z, amount or 0))
		MoneyVFX.PlayCollectionEffect(pos)
		if amount and amount > 0 then
			RewardUI.ShowReward(amount)
		end
	end)

	-- 🏁 顔ターゲット破壊演出
	Net.On("FaceTargetDestroyed", function(data)
		print("[CanController] 🔊 RECEIVED FaceTargetDestroyed!")
		print("[CanController] UI Data:", data.displayName, "Reward:", data.totalReward)
		
		if data.displayName and data.totalReward then
			print("[CanController] Triggering FaceTargetSummaryUI.Show...")
			FaceTargetSummaryUI.Show(data.displayName, data.totalReward)
			CanVFX.PlayFaceClearSound() -- 豪華な音を鳴らす
		else
			warn("[CanController] FaceTargetDestroyed received but missing data:", data.displayName, data.totalReward)
		end
	end)

	local function findTargetModelById(targetId)
		local folder = workspace:FindFirstChild("FaceTargets")
		if not folder then return nil end
		for _, model in ipairs(folder:GetChildren()) do
			if model:GetAttribute("FaceTargetId") == targetId then
				return model
			end
		end
		return nil
	end

	-- ⏳ 顔ターゲット消滅予告（フェードアウト開始）
	Net.On("FaceTargetExpiring", function(data)
		print("[CanController] FaceTarget expiring soon:", data.targetId)
		local model = findTargetModelById(data.targetId)
		if model then
			CanVFX.FadeOutModel(model, data.duration)
		end
	end)

	-- 💢 顔ターゲット被弾演出（ヒットフラッシュ・シェイク・サウンド）
	Net.On("FaceTargetDamaged", function(data)
		print("[CanController] FaceTargetDamaged received:", data.targetId, "newHP:", data.newHP)
		local model = findTargetModelById(data.targetId)
		if model then
			-- HPがある時だけ演出（0の時は即座に消えるためスキップ）
			if data.newHP > 0 then
				print("[CanController] Playing hit effects for:", model.Name)
				CanVFX.PlayFaceHitFlash(model)
				CanVFX.ShakeFace(model)
			end
			-- 音は最後の一撃でも鳴らす
			CanVFX.PlayFaceHitSound()
		else
			warn("[CanController] Model not found for targetId:", data.targetId)
		end
	end)
	
	-- 顔ターゲットUI初期化
	print("[CanController] DEBUG: Calling FaceTargetUI.Init()...")
	FaceTargetUI.Init()
	print("[CanController] DEBUG: FaceTargetUI.Init() Done.")
	
	local function onFaceAdded(m)
		if not m:IsA("Model") then return end
		-- 顔ターゲットかどうか判定 (名前または属性)
		if not (string.find(m.Name, "Face") or m:GetAttribute(FaceTargetConfig.AttrTargetId)) then
			return
		end
		
		print("[CanController] Face detected. Creating UI and binding Touched for:", m.Name)
		
		-- 1. UI生成 (HPバー)
		FaceTargetUI.CreateHealthBar(m)

		-- 2. 物理接触判定 (缶と同様の挙動に)
		local bp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		if bp then
			bp.Touched:Connect(function(hit)
				if hit:IsDescendantOf(player.Character) and isPointerDown then
					local tid = m:GetAttribute(FaceTargetConfig.AttrTargetId)
					if tid then
						-- 連続ヒット防止用の簡易クールダウン (0.1秒)
						local lastTouch = m:GetAttribute("LastTouchHit") or 0
						if tick() - lastTouch > 0.1 then
							m:SetAttribute("LastTouchHit", tick())
							Net.Fire("FaceTargetHit", tid)
							print("[CanController] Face hit by Physical Touch (Active Smashing)!")
						end
					end
				end
			end)
		end
	end
	
	-- 既存のものをチェック
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") then task.spawn(onFaceAdded, m) end
	end
	
	-- 新しく追加されるものを監視 (Workspace全体)
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("Model") then onFaceAdded(desc) end
	end)

	print("[CanController] Production Version Ready.")
end

return CanController

