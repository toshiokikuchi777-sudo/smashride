-- ServerScriptService/Core/GrindSystemInit.server.lua
-- グラインドシステムの初期化スクリプト

local ServerScriptService = game:GetService("ServerScriptService")
local ServicesFolder = ServerScriptService:WaitForChild("Services")

print("[GrindSystemInit] Starting grind system initialization...")

-- GrindServiceを読み込んで初期化
local success, result = pcall(function()
	local GrindService = require(ServicesFolder:WaitForChild("GrindService"))
	GrindService.Init()
	return GrindService
end)

if success then
	print("[GrindSystemInit] ✅ Grind system initialized successfully")
else
	warn("[GrindSystemInit] ❌ Failed to initialize grind system:")
	warn(tostring(result))
end
