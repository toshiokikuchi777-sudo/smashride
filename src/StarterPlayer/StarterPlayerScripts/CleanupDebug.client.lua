local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local BLOCKER_NAME = "DebugInput"

print("[CleanupDebug] v2 Active. Hunting for " .. BLOCKER_NAME .. " and clearing blockers...")

-- Utility: Destroy target if found
local function checkAndDestroy(parent)
	if not parent then return end
	local target = parent:FindFirstChild(BLOCKER_NAME, true)
	if target then
		warn("[CleanupDebug] 💥 FOUND & DESTROYED " .. target:GetFullName())
		target:Destroy()
	end
end

-- Utility: Clear input sinks
local function sanitizeGui()
	-- 1. Unlock Mouse if stuck
	if UserInputService.ModalEnabled then
		warn("[CleanupDebug] 🔓 ModalEnabled detected! Forcing false.")
		UserInputService.ModalEnabled = false
	end

	-- 2. Clear SelectedObject (Gamepad focus)
	if GuiService.SelectedObject then
		warn("[CleanupDebug] 🔓 SelectedObject detected (" .. GuiService.SelectedObject.Name .. ")! Clearing.")
		GuiService.SelectedObject = nil
	end

	-- 3. Hunt for Invisible Blockers
	local candidates = PlayerGui:GetDescendants()
	for _, gui in ipairs(candidates) do
		if gui:IsA("GuiObject") and gui.Visible and gui.Active then
			-- Identify suspicious full-screen invisible frames
			local isTransparent = (gui.BackgroundTransparency >= 0.95)
			local isBig = (gui.AbsoluteSize.X > 500 and gui.AbsoluteSize.Y > 400)
			
			-- Also check for "DebugInput" within the Gui name itself
			if gui.Name == BLOCKER_NAME then
				warn("[CleanupDebug] 💥 Destroying GUI named DebugInput: " .. gui:GetFullName())
				gui:Destroy()
			elseif isTransparent and isBig then
				-- Don't destroy valid containers, just disable Active
				-- But if it's "DebugInput" related, destroy it
				if gui.Name:match("Debug") or gui.Name:match("Blocker") then
					warn("[CleanupDebug] 💥 Destroying suspicious blocker: " .. gui:GetFullName())
					gui:Destroy()
				else
					-- Just disable interaction
					gui.Active = false
					-- warn("[CleanupDebug] 🛡️ Disabled Active on invisible frame: " .. gui.Name) 
				end
			end
			
			-- Remove Modal if set on any button
			if gui:IsA("TextButton") or gui:IsA("ImageButton") then
				if gui.Modal then
					warn("[CleanupDebug] 🔓 Found Modal button: " .. gui.Name .. " -> Disabling Modal")
					gui.Modal = false
				end
			end
		end
	end
end

-- Main Loop
task.spawn(function()
	while true do
		-- Search everywhere
		checkAndDestroy(player.Character)
		checkAndDestroy(player:FindFirstChild("Backpack"))
		checkAndDestroy(player:FindFirstChild("PlayerScripts"))
		checkAndDestroy(PlayerGui)
		
		-- Sanitize
		sanitizeGui()
		
		task.wait(0.5)
	end
end)
