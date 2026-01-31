-- ReplicatedStorage/Shared/Net.lua
-- Remotesへのアクセスを1箇所に集約し、直叩きを禁止するラッパ（指示書 2/4 準拠）

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))

local Net = {}

local function getRemotesFolder()
	local folder = ReplicatedStorage:FindFirstChild(Constants.RemotesFolderName)
	if not folder then
		error(("Net: Remotes folder '%s' not found in ReplicatedStorage"):format(Constants.RemotesFolderName))
	end
	return folder
end

local function resolveName(map, key, kind)
	local name = map[key]
	if not name then
		error(("Net: %s key '%s' is not defined in Constants"):format(kind, tostring(key)))
	end
	return name
end

-- RemoteEvent取得（存在しない場合は作成）
function Net.E(key)
	local folder = getRemotesFolder()
	local remoteName = resolveName(Constants.Events, key, "Event")
	local obj = folder:FindFirstChild(remoteName)
	if not obj then
		-- サーバー側でのみ作成。クライアント側では作成を禁止し、待機のみとする。
		local RunService = game:GetService("RunService")
		if RunService:IsServer() then
			obj = Instance.new("RemoteEvent")
			obj.Name = remoteName
			obj.Parent = folder
			print(("[Net] Created RemoteEvent: %s"):format(remoteName))
		else
			-- クライアント側では待機（タイムアウトを設ける）
			obj = folder:WaitForChild(remoteName, 10)
			if not obj then
				error(("Net: RemoteEvent '%s' (key=%s) not found under Remotes (Client side wait timeout)"):format(remoteName, tostring(key)))
			end
		end
	end
	if not obj:IsA("RemoteEvent") then
		error(("Net: '%s' exists but is not a RemoteEvent"):format(remoteName))
	end
	return obj
end

-- RemoteFunction取得（存在しない場合は作成）
function Net.F(key)
	local folder = getRemotesFolder()
	local remoteName = resolveName(Constants.Functions, key, "Function")
	local obj = folder:FindFirstChild(remoteName)
	if not obj then
		-- サーバー側でのみ作成。
		local RunService = game:GetService("RunService")
		if RunService:IsServer() then
			obj = Instance.new("RemoteFunction")
			obj.Name = remoteName
			obj.Parent = folder
			print(("[Net] Created RemoteFunction: %s"):format(remoteName))
		else
			-- クライアント側では待機
			obj = folder:WaitForChild(remoteName, 10)
			if not obj then
				error(("Net: RemoteFunction '%s' (key=%s) not found under Remotes (Client side wait timeout)"):format(remoteName, tostring(key)))
			end
		end
	end
	if not obj:IsA("RemoteFunction") then
		error(("Net: '%s' exists but is not a RemoteFunction"):format(remoteName))
	end
	return obj
end

-- ヘルパー関数: RemoteEventにイベントリスナーを登録
function Net.On(key, callback)
	local remote = Net.E(key)
	if game:GetService("RunService"):IsServer() then
		remote.OnServerEvent:Connect(callback)
	else
		remote.OnClientEvent:Connect(callback)
	end
end

-- ヘルパー関数: RemoteEventを発火
function Net.Fire(key, ...)
	local remote = Net.E(key)
	if game:GetService("RunService"):IsServer() then
		remote:FireAllClients(...)
	else
		remote:FireServer(...)
	end
end

-- ヘルパー関数: RemoteFunctionを呼び出し
function Net.Invoke(key, ...)
	local remote = Net.F(key)
	if game:GetService("RunService"):IsServer() then
		error("Net.Invoke should not be called on server for RemoteFunction")
	else
		return remote:InvokeServer(...)
	end
end

return Net
