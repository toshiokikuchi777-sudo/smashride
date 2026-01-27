local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local localPlayer = Players.LocalPlayer

local PetController = {}

--// 状態管理
-- currentPets[player] = { [slotIndex] = petModel }
local currentPets = {}        
local followConnection = nil
local childAddedConn = nil
local globalScope             -- 接続管理スコープ
local playerScopes = {}       -- [player] = Scope

--// 設定
local PET_OFFSETS = {
	[1] = Vector3.new(0, 3, 3),   -- 真後ろ
	[2] = Vector3.new(-2, 3, 2),  -- 左後ろ
	[3] = Vector3.new(2, 3, 2),   -- 右後ろ
}
local LERP_SPEED = 0.1
local SCAN_INTERVAL = 1.0     -- 定期スキャンの秒数

----------------------------------------------------------------
-- 追従ループ（Heartbeat）: 全プレイヤーのペットを処理
----------------------------------------------------------------
local function startGlobalHeartbeat()
	if followConnection then followConnection:Disconnect() end
	
	followConnection = RunService.Heartbeat:Connect(function()
		local totalPetsFound = 0
		
		for targetPlayer, slots in pairs(currentPets) do
			local char = targetPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then continue end

			for slot, pet in pairs(slots) do
				if pet and pet.Parent then
					totalPetsFound = totalPetsFound + 1
					local offset = PET_OFFSETS[slot] or PET_OFFSETS[1]
					
					-- [FIX] 目標CFrameの計算（水平方向の向きのみを抽出）
					local targetPos = root.Position + root.CFrame:VectorToWorldSpace(offset)
					
					-- プレイヤーの水平方向の向きだけを抽出して適用（ひっくり返りを防止）
					local _, yRotation, _ = root.CFrame:ToEulerAnglesYXZ()
					local targetCFrame = CFrame.new(targetPos) * CFrame.Angles(0, yRotation, 0)
					
					-- PivotTo主体でLerp追従
					local currentCFrame = pet:GetPivot()
					pet:PivotTo(currentCFrame:Lerp(targetCFrame, LERP_SPEED))
				else
					slots[slot] = nil
				end
			end
		end
		
		-- 全くペットがいなくなっても、プレイヤーの入り待ちなどのためループは維持（または止めて再スキャンで再開）
		if totalPetsFound == 0 and #Players:GetPlayers() == 1 then
			-- 特殊な最適化が必要ならここでするが、基本的には回しておいてOK
		end
	end)
end

----------------------------------------------------------------
-- ペットの再検索ロジック（全プレイヤー対象）
----------------------------------------------------------------
local function scanAllPets()
	-- 期待される装備情報を属性から取得
	local playerExpectations = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local equippedStr = p:GetAttribute("EquippedPets") or ""
		local types = (equippedStr ~= "") and string.split(equippedStr, ",") or {}
		local slots = {}
		for i, t in ipairs(types) do
			if t ~= "" then slots[i] = t end
		end
		playerExpectations[p.UserId] = { player = p, slots = slots }
	end

	-- Workspace内の全ペットをチェック
	for _, child in ipairs(workspace:GetChildren()) do
		local ownerId = child:GetAttribute("OwnerUserId")
		if not ownerId then
			-- Fallback: 名前から推測 (petType_PlayerName_Slot)
			local parts = string.split(child.Name, "_")
			if #parts >= 3 then
				local playerName = parts[2]
				local targetP = Players:FindFirstChild(playerName)
				if targetP then ownerId = targetP.UserId end
			end
		end

		if ownerId and playerExpectations[ownerId] then
			local data = playerExpectations[ownerId]
			local p = data.player
			local slot = child:GetAttribute("SlotIndex")
			
			-- SlotIndex属性がない場合のフォールバック（名前の末尾）
			if not slot then
				local parts = string.split(child.Name, "_")
				slot = tonumber(parts[#parts])
			end

			if slot and data.slots[slot] then
				if not currentPets[p] then currentPets[p] = {} end
				
				if currentPets[p][slot] ~= child then
					currentPets[p][slot] = child
					-- print("[PetController] Linked pet for", p.Name, "slot", slot)
					
					-- 物理挙動の安定化
					for _, part in ipairs(child:GetDescendants()) do
						if part:IsA("BasePart") then
							-- 自分がオーナーならネットワークオーナーなのでAnchored=trueで制御
							-- 他人ならネットワークオーナーではないが、見た目の追従のためAnchored=trueにする
							part.Anchored = true
							part.CanCollide = false
						end
					end
				end
			end
		end
	end

	-- 心拍開始（まだなら）
	if not followConnection then
		startGlobalHeartbeat()
	end
end

----------------------------------------------------------------
-- 個別プレイヤーの管理
----------------------------------------------------------------
local function setupPlayer(p)
	if playerScopes[p] then playerScopes[p]:Destroy() end
	local scope = Signal.new()
	playerScopes[p] = scope

	-- 装備変更監視
	scope:Connect(p:GetAttributeChangedSignal("EquippedPets"), function()
		scanAllPets()
	end)

	-- キャラリスポーン監視
	scope:Connect(p.CharacterAdded, function()
		task.wait(0.5)
		scanAllPets()
	end)
end

local function removePlayer(p)
	if playerScopes[p] then
		playerScopes[p]:Destroy()
		playerScopes[p] = nil
	end
	currentPets[p] = nil
end

----------------------------------------------------------------
-- API
----------------------------------------------------------------
function PetController.Init()
	print("[PetController] Multiplayer Init Starting...")
	
	globalScope = Signal.new()

	-- 既存プレイヤーのセットアップ
	for _, p in ipairs(Players:GetPlayers()) do
		setupPlayer(p)
	end

	-- 新規・退出監視
	globalScope:Connect(Players.PlayerAdded, function(p)
		setupPlayer(p)
	end)
	globalScope:Connect(Players.PlayerRemoving, function(p)
		removePlayer(p)
	end)

	-- 定期スキャン（同期漏れ防止）
	task.spawn(function()
		while true do
			task.wait(SCAN_INTERVAL)
			scanAllPets()
		end
	end)

	-- 倍率同期（ローカルプレイヤーのみ関係するが、コントローラーにあるので維持）
	local Net = require(ReplicatedStorage.Shared.Net)
	globalScope:Connect(Net.E("EffectStateSync").OnClientEvent, function(payload)
		if typeof(payload) ~= "table" then return end
		local petBonusMult = payload.petBonusMult or 1
		local hammerMult = payload.hammerMult or 1
		local totalMult = payload.totalMult or (petBonusMult * hammerMult)

		localPlayer:SetAttribute("PetBonusMult", petBonusMult)
		localPlayer:SetAttribute("HammerMult", hammerMult)
		localPlayer:SetAttribute("TotalMult", totalMult)
	end)

	-- 初回スキャン
	scanAllPets()
	
	print("[PetController] Multiplayer Init End")
end

return PetController
