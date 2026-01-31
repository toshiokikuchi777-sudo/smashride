local player = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

print("--- CLICK TRACKER ACTIVE ---")

UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local pos = input.Position
        print("Click detected at:", pos)
        print("Processed by Game Engine:", processed)
        
        local objects = player.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
        if #objects > 0 then
            print("GUIs at this position (Top to Bottom):")
            for i, obj in ipairs(objects) do
                print(string.format("  [%d] %s | Visible: %s | Active: %s | ZIndex: %d", 
                    i, obj:GetFullName(), tostring(obj.Visible), tostring(obj.Active), obj.ZIndex))
            end
        else
            print("No GUI objects found at this position.")
        end
    end
end)
