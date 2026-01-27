-- StarterPlayer/StarterPlayerScripts/GrindJumpClient.lua
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = game.Players.LocalPlayer
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Constants"))
local remotes = ReplicatedStorage:WaitForChild(Constants.RemotesFolderName)
local jumpEvent = remotes:WaitForChild(Constants.Events.SkateboardGrindJump)

UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute(Constants.Attr.IsGrinding) then
		jumpEvent:FireServer()
	end
end)
