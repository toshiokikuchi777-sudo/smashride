-- ServerScriptService/Services/SkateboardShopService.lua
-- スケボーショップのサーバー側処理

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkateboardShopService = {}

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local SkateboardShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SkateboardShopConfig"))

-- DataService と CanService への参照（遅延取得）
local DataService
local CanService
local SkateboardService

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

local function getSkateboardService()
	if not SkateboardService then
		SkateboardService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("SkateboardService"))
	end
	return SkateboardService
end

-- スケボー購入処理
function SkateboardShopService.PurchaseSkateboard(player, skateboardId)
	print("[SkateboardShopService] Purchase request:", player.Name, skateboardId)
	
	local config = SkateboardShopConfig.Skateboards[skateboardId]
	if not config then
		warn("[SkateboardShopService] Invalid skateboard ID:", skateboardId)
		return false, "無効なスケボーです"
	end
	
	local DS = getDataService()
	if not DS then
		warn("[SkateboardShopService] DataService not available")
		return false, "サーバーエラー"
	end
	
	local data = DS.Get(player)
	if not data then
		warn("[SkateboardShopService] Player data not found")
		return false, "データが見つかりません"
	end
	
	-- 既に所持しているかチェック
	for _, owned in ipairs(data.ownedSkateboards) do
		if owned == skateboardId then
			return false, "既に所持しています"
		end
	end
	
	-- SCRAP が足りるかチェック
	if data.total < config.cost then
		return false, "SCRAP が足りません"
	end
	
	-- SCRAP を消費
	data.total = data.total - config.cost
	
	-- スケボーを追加
	table.insert(data.ownedSkateboards, skateboardId)
	
	-- 購入したスケボーを自動装着（データ更新）
	data.equippedSkateboard = skateboardId
	
	-- データを保存
	DS.MarkDirty(player)
	
	-- スコア同期（CanService経由）
	local CS = getCanService()
	if CS then
		CS.SetTotalScore(player, data.total, string.format("-%d (スケボー購入)", config.cost))
	end
	
	-- 実際にキャラクターに装着（SkateboardService経由）
	local SS = getSkateboardService()
	if SS then
		SS.EquipSkateboard(player)
	end
	
	print("[SkateboardShopService] Purchase successful and auto-equipped:", player.Name, skateboardId)
	return true, "購入して装着しました！"
end

-- スケボー装備変更
function SkateboardShopService.EquipSkateboard(player, skateboardId)
	print("[SkateboardShopService] Equip request:", player.Name, skateboardId)
	
	-- NONEは装備解除として許可
	if skateboardId ~= "NONE" then
		local config = SkateboardShopConfig.Skateboards[skateboardId]
		if not config then
			warn("[SkateboardShopService] Invalid skateboard ID:", skateboardId)
			return false
		end
	end
	
	local DS = getDataService()
	if not DS then return false end
	
	local data = DS.Get(player)
	if not data then return false end
	
	-- NONEの場合は装備解除
	if skateboardId == "NONE" then
		data.equippedSkateboard = "NONE"
		player:SetAttribute("EquippedSkateboard", "NONE")
		-- スケートボードを削除
		local SkateboardService = require(script.Parent.SkateboardService)
		SkateboardService.RemoveSkateboard(player)
		DS.MarkDirty(player)
		return { success = true }
	end
	
	-- 所持しているかチェック
	local owned = false
	for _, id in ipairs(data.ownedSkateboards) do
		if id == skateboardId then
			owned = true
			break
		end
	end
	
	if not owned then
		warn("[SkateboardShopService] Player doesn't own this skateboard")
		return false
	end
	
	-- 装備を変更（データ更新）
	data.equippedSkateboard = skateboardId
	DS.MarkDirty(player)
	
	-- 実際にキャラクターに装着（SkateboardService経由）
	local SS = getSkateboardService()
	if SS then
		SS.EquipSkateboard(player)
	end
	
	print("[SkateboardShopService] Equipped:", player.Name, skateboardId)
	return true
end

-- プレイヤーのスケボーデータを取得
function SkateboardShopService.GetPlayerSkateboards(player)
	local DS = getDataService()
	if not DS then return nil end
	
	local data = DS.Get(player)
	if not data then return nil end
	
	return {
		owned = data.ownedSkateboards,
		equipped = data.equippedSkateboard,
		scrap = data.total
	}
end

-- 初期化
function SkateboardShopService.Init()
	print("[SkateboardShopService] Init")
	
	-- RemoteFunction: スケボー購入
	local PurchaseSkateboardFunc = Net.F(Constants.Functions.PurchaseSkateboard)
	PurchaseSkateboardFunc.OnServerInvoke = function(player, skateboardId)
		local success, message = SkateboardShopService.PurchaseSkateboard(player, skateboardId)
		return {success = success, message = message}
	end
	
	-- RemoteFunction: スケボー装備
	local EquipSkateboardFunc = Net.F(Constants.Functions.EquipSkateboard)
	EquipSkateboardFunc.OnServerInvoke = function(player, skateboardId)
		local success = SkateboardShopService.EquipSkateboard(player, skateboardId)
		return {success = success}
	end
	
	-- RemoteFunction: スケボーデータ取得
	local GetSkateboardsFunc = Net.F(Constants.Functions.GetPlayerSkateboards)
	GetSkateboardsFunc.OnServerInvoke = function(player)
		return SkateboardShopService.GetPlayerSkateboards(player)
	end
	
	print("[SkateboardShopService] Remotes registered")
end

return SkateboardShopService
