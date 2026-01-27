-- ServerScriptService/Services/HammerShopService.lua
-- ハンマーショップのサーバー側処理

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HammerShopService = {}

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local HammerShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HammerShopConfig"))

-- DataService と CanService への参照（遅延取得）
local DataService
local CanService

local function getDataService()
	if not DataService then
		DataService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataService"))
	end
	return DataService
end

local function getCanService()
	if not CanService then
		CanService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("CanService"))
	end
	return CanService
end

-- ハンマー購入処理
function HammerShopService.PurchaseHammer(player, hammerId)
	print("[HammerShopService] Purchase request:", player.Name, hammerId)
	
	local config = HammerShopConfig.Hammers[hammerId]
	if not config then
		warn("[HammerShopService] Invalid hammer ID:", hammerId)
		return false, "無効なハンマーです"
	end
	
	local DS = getDataService()
	if not DS then
		warn("[HammerShopService] DataService not available")
		return false, "サーバーエラー"
	end
	
	local data = DS.Get(player)
	if not data then
		warn("[HammerShopService] Player data not found")
		return false, "データが見つかりません"
	end
	
	-- 既に所持しているかチェック
	for _, owned in ipairs(data.ownedHammers) do
		if owned == hammerId then
			return false, "既に所持しています"
		end
	end
	
	-- SCRAP が足りるかチェック
	if config.isSpecial then
		return false, "コミュニティ参加で獲得できます！"
	end
	
	if data.total < config.cost then
		return false, "SCRAP が足りません"
	end
	
	-- SCRAP を消費
	data.total = data.total - config.cost
	
	-- ハンマーを追加
	table.insert(data.ownedHammers, hammerId)
	
	-- 購入したハンマーを自動装着（データ更新）
	data.equippedHammer = hammerId
	
	-- データを保存
	DS.MarkDirty(player)
	
	-- プレイヤーのAttributeを更新してハンマーを視覚的に反映
	player:SetAttribute("EquippedHammer", hammerId)
	
	-- スコア同期（CanService経由）
	local CS = getCanService()
	if CS then
		CS.SetTotalScore(player, data.total, string.format("-%d (ハンマー購入)", config.cost))
	end
	
	print("[HammerShopService] Purchase successful and auto-equipped:", player.Name, hammerId)
	return true, "購入して装着しました！"
end

-- ハンマー装備変更
function HammerShopService.EquipHammer(player, hammerId)
	print("[HammerShopService] Equip request:", player.Name, hammerId)
	
	-- NONEは装備解除として許可
	if hammerId ~= "NONE" then
		local config = HammerShopConfig.Hammers[hammerId]
		if not config then
			warn("[HammerShopService] Invalid hammer ID:", hammerId)
			return false
		end
	end
	
	local DS = getDataService()
	if not DS then return false end
	
	local data = DS.Get(player)
	if not data then return false end
	
	-- NONEの場合は装備解除
	if hammerId == "NONE" then
		data.equippedHammer = "NONE"
		player:SetAttribute("EquippedHammer", "NONE")
		DS.MarkDirty(player)
		return { success = true }
	end
	
	-- 所持しているかチェック
	local owned = false
	for _, id in ipairs(data.ownedHammers) do
		if id == hammerId then
			owned = true
			break
		end
	end
	
	if not owned then
		warn("[HammerShopService] Player doesn't own this hammer")
		return false
	end
	
	-- 装備を変更（データ更新）
	data.equippedHammer = hammerId
	DS.MarkDirty(player)
	
	-- プレイヤーのAttributeを更新してハンマーを視覚的に反映
	player:SetAttribute("EquippedHammer", hammerId)
	
	print("[HammerShopService] Equipped:", player.Name, hammerId)
	return true
end

-- プレイヤーのハンマーデータを取得
function HammerShopService.GetPlayerHammers(player)
	local DS = getDataService()
	if not DS then return nil end
	
	local data = DS.Get(player)
	if not data then return nil end
	
	return {
		owned = data.ownedHammers,
		equipped = data.equippedHammer,
		scrap = data.total
	}
end

-- 初期化
function HammerShopService.Init()
	print("[HammerShopService] Init")
	
	local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
	
	-- RemoteFunction: ハンマー購入
	local PurchaseHammerFunc = Net.F(Constants.Functions.PurchaseHammer)
	PurchaseHammerFunc.OnServerInvoke = function(player, hammerId)
		local success, message = HammerShopService.PurchaseHammer(player, hammerId)
		return {success = success, message = message}
	end
	
	-- RemoteFunction: ハンマー装備
	local EquipHammerFunc = Net.F(Constants.Functions.EquipHammer)
	EquipHammerFunc.OnServerInvoke = function(player, hammerId)
		local success = HammerShopService.EquipHammer(player, hammerId)
		return {success = success}
	end
	
	-- RemoteFunction: ハンマーデータ取得
	local GetHammersFunc = Net.F(Constants.Functions.GetPlayerHammers)
	GetHammersFunc.OnServerInvoke = function(player)
		return HammerShopService.GetPlayerHammers(player)
	end
	
	print("[HammerShopService] Remotes registered")
end

return HammerShopService
