-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL (FIXED V4)
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
    CurrentSpeedMultiplier = 1.0
}

local maxBonusJumps = 10
local jumpCount = 0

-- ---------------------------------------------------------------------
--  1. AUTOMATION & CHARACTER LOGIC
-- ---------------------------------------------------------------------

-- Aggressive No Ragdoll / State Manager
RunService.RenderStepped:Connect(function()
    if ProfileSettings.NoRagdollActive and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            -- Force-keep state to Running/None to prevent falling animations/physics
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end
    end
end)

-- Auto Buy Loop
task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage
    local buyRemote = remotes:FindFirstChild("BuyBomb") or remotes:FindFirstChild("PurchaseBomb")
    local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}
    
    while true do
        if ProfileSettings.AutoBuyActive and buyRemote then
            for _, name in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function() if buyRemote:IsA("RemoteFunction") then buyRemote:InvokeServer(name) else buyRemote:FireServer(name) end end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

-- Multi-Jump Logic
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or input.KeyCode ~= Enum.KeyCode.Space or not ProfileSettings.MultiJumpActive then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and (hum:GetState() == Enum.HumanoidStateType.Freefall or hum:GetState() == Enum.HumanoidStateType.Jumping) then
        if jumpCount < maxBonusJumps then
            jumpCount += 1
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Reset jumps on ground
LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid").StateChanged:Connect(function(_, state)
        if state == Enum.HumanoidStateType.Landed then jumpCount = 0 end
    end)
end)

-- ---------------------------------------------------------------------
--  2. GUI SYSTEM
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 240, 0, 260)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local function createToggle(name, yPos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.Text = name .. ": OFF"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.BackgroundColor3 = on and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(45, 45, 45)
        btn.Text = name .. (on and ": ON" or ": OFF")
        callback(on)
    end)
end

createToggle("Auto Buy Bombs", 45, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 90, function(s) ProximityPromptService.PromptButtonHoldBegan:Connect(function(p) p.HoldDuration = 0 end) end)
createToggle("No Ragdoll", 135, function(s) ProfileSettings.NoRagdollActive = s end)
createToggle("Infinite Multi-Jump", 180, function(s) ProfileSettings.MultiJumpActive = s end)

-- Fixed Speed Slider
local SliderTrack = Instance.new("Frame", MainFrame)
SliderTrack.Size = UDim2.new(0.9, 0, 0, 8)
SliderTrack.Position = UDim2.new(0.05, 0, 0, 230)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(0, 4)

local Knob = Instance.new("TextButton", SliderTrack)
Knob.Size = UDim2.new(0, 16, 0, 16)
Knob.Position = UDim2.new(0, -8, 0.5, -8)
Knob.Text = ""
Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

Knob.MouseButton1Down:Connect(function()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local rel = math.clamp((LocalPlayer:GetMouse().X - SliderTrack.AbsolutePosition.X) / SliderTrack.AbsoluteSize.X, 0, 1)
        Knob.Position = UDim2.new(rel, -8, 0.5, -8)
        local speed = 16 + (rel * 32) -- Scales from 16 to 48
        ProfileSettings.CurrentSpeedMultiplier = speed / 16
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = speed
        end
    end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then conn:Disconnect() end end)
end)

UserInputService.InputBegan:Connect(function(i, gpe) if not gpe and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
