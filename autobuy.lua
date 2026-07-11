-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL (FIXED V6)
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    NoRagdollActive = false,
    MultiJumpActive = false,
    SpeedValue = 16
}

-- 1. GUI SETUP (Explicit parenting)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 300)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "AUTOMATION PANEL"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Bold
Title.TextSize = 18
Title.BackgroundTransparency = 1

-- 2. LOGIC
RunService.RenderStepped:Connect(function()
    if ProfileSettings.NoRagdollActive and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end
    end
end)

-- 3. COMPONENTS
local function createToggle(name, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = name .. ": OFF"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.BackgroundColor3 = on and Color3.fromRGB(70, 150, 70) or Color3.fromRGB(50, 50, 50)
        btn.Text = name .. (on and ": ON" or ": OFF")
        callback(on)
    end)
end

createToggle("Auto Buy", 50, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant Mine", 95, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("No Ragdoll", 140, function(s) ProfileSettings.NoRagdollActive = s end)
createToggle("Multi-Jump", 185, function(s) ProfileSettings.MultiJumpActive = s end)

-- Speed Slider
local SpeedLabel = Instance.new("TextLabel", MainFrame)
SpeedLabel.Size = UDim2.new(0.9, 0, 0, 20)
SpeedLabel.Position = UDim2.new(0.05, 0, 0, 230)
SpeedLabel.Text = "Walk Speed: 1.0x"
SpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedLabel.BackgroundTransparency = 1

local Track = Instance.new("Frame", MainFrame)
Track.Size = UDim2.new(0.9, 0, 0, 10)
Track.Position = UDim2.new(0.05, 0, 0, 255)
Track.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Instance.new("UICorner", Track).CornerRadius = UDim.new(0, 5)

local Knob = Instance.new("TextButton", Track)
Knob.Size = UDim2.new(0, 20, 0, 20)
Knob.Position = UDim2.new(0, -10, 0.5, -10)
Knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

Knob.MouseButton1Down:Connect(function()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local rel = math.clamp((LocalPlayer:GetMouse().X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Knob.Position = UDim2.new(rel, -10, 0.5, -10)
        local multiplier = 1 + (rel * 4)
        SpeedLabel.Text = "Walk Speed: " .. string.format("%.1f", multiplier) .. "x"
        ProfileSettings.SpeedValue = 16 * multiplier
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            conn:Disconnect()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.WalkSpeed = ProfileSettings.SpeedValue
            end
        end
    end)
end)

UserInputService.InputBegan:Connect(function(i, gpe) if not gpe and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
