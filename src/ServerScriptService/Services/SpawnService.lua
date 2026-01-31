-- ServerScriptService/Services/SpawnService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local SpawnService = {}

-- スポーンのリクエスト
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local RE_RequestSpawn = Net.E(Constants.Events.RequestSpawn)

function SpawnService.TeleportToSpawn(player)
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    print("[SpawnService] Teleporting player to spawn:", player.Name)
    
    -- スポーン地点の特定 (優先：WorldSpawn -> SpawnLocation -> 初期位置)
    local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    local targetCF = CFrame.new(0, 5, 0) -- デフォルト
    
    if spawnLocation then
        targetCF = spawnLocation.CFrame + Vector3.new(0, 5, 0)
    end
    
    -- テレポート（物理的な干渉を避けるため PivotTo を使用）
    char:PivotTo(targetCF)
end

function SpawnService.Init()
    print("[SpawnService] Init")
    
    RE_RequestSpawn.OnServerEvent:Connect(function(player)
        -- クールダウン等の処理が必要な場合はここに追加
        SpawnService.TeleportToSpawn(player)
    end)
end

return SpawnService
