-- ReplicatedStorage/Shared/Signal.lua
-- 接続管理用の簡易クラス（指示書 3/4 用）

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_connections = {}
	}, Signal)
end

function Signal:Connect(event, callback)
	local conn = event:Connect(callback)
	table.insert(self._connections, conn)
	return conn
end

function Signal:Destroy()
	for _, conn in ipairs(self._connections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	self._connections = {}
end

return Signal
