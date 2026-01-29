-- このスクリプトをRoblox Studioのコマンドバーで実行してください
-- Workspace に GrindRails フォルダとサンプルレールを作成します

local CollectionService = game:GetService("CollectionService")
local workspace = game.Workspace

-- Create folder for rails
local grindRailsFolder = workspace:FindFirstChild("GrindRails")
if not grindRailsFolder then
	grindRailsFolder = Instance.new("Folder")
	grindRailsFolder.Name = "GrindRails"
	grindRailsFolder.Parent = workspace
end

-- Create a sample rail (long horizontal bar)
local rail1 = Instance.new("Part")
rail1.Name = "SampleRail_1"
rail1.Size = Vector3.new(20, 0.5, 0.5) -- Long horizontal rail
rail1.Position = Vector3.new(0, 5, 0) -- 5 studs above ground
rail1.Anchored = true
rail1.CanCollide = false -- Players should pass through
rail1.Material = Enum.Material.Metal
rail1.Color = Color3.fromRGB(150, 150, 150) -- Gray metal
rail1.Parent = grindRailsFolder

-- Add GRIND_RAIL tag
CollectionService:AddTag(rail1, "GRIND_RAIL")

-- Create another rail at a different location
local rail2 = Instance.new("Part")
rail2.Name = "SampleRail_2"
rail2.Size = Vector3.new(15, 0.5, 0.5)
rail2.Position = Vector3.new(25, 6, 10)
rail2.Anchored = true
rail2.CanCollide = false
rail2.Material = Enum.Material.Metal
rail2.Color = Color3.fromRGB(150, 150, 150)
rail2.Parent = grindRailsFolder

CollectionService:AddTag(rail2, "GRIND_RAIL")

-- Create a curved rail (angled)
local rail3 = Instance.new("Part")
rail3.Name = "SampleRail_3_Angled"
rail3.Size = Vector3.new(18, 0.5, 0.5)
rail3.Position = Vector3.new(-20, 7, -10)
rail3.Orientation = Vector3.new(0, 45, 0) -- 45 degree angle
rail3.Anchored = true
rail3.CanCollide = false
rail3.Material = Enum.Material.Metal
rail3.Color = Color3.fromRGB(150, 150, 150)
rail3.Parent = grindRailsFolder

CollectionService:AddTag(rail3, "GRIND_RAIL")

print("✅ Created 3 sample grind rails in Workspace/GrindRails")
print("✅ All rails tagged with 'GRIND_RAIL'")
print("✅ Rails are set to CanCollide = false (players pass through)")
print("✅ Rails are anchored and made of Metal material")
