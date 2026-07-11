-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL (V3)
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    NoRagdollActive = false,
    MultiJumpActive = false,
    CurrentSpeedMultiplier = 1.0,
    LuckBoostValue = 0
}

local maxBonusJumps = 10
local jumpCount = 0

-- ---------------------------------------------------------------------
--  1. AUTOMATION & CORE LOOPS
-- ---------------------------------------------------------------------
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage
local BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
local LUCK_REMOTE = remotesFolder:FindFirstChild("CrystalLuck") or remotesFolder:FindFirstChild("CrystalBoost")

-- Instant Mine Loop
task.spawn(function()
    while true do
        if ProfileSettings.InstantInteractions then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end
            end
        end
        task.wait(1)
    end
end)

-- No Ragdoll Loop
task.spawn(function()
    while true do
        if ProfileSettings.NoRagdollActive and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                -- Disable ragdoll-related states if they exist
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
                end)
            end
        end
        task.wait(0.5)
    end
end)

-- Auto Buy Loop
task.spawn(function()
    local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            for _, name in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function() if BUY_BOMB_REMOTE:IsA("RemoteFunction") then BUY_BOMB_REMOTE:InvokeServer(name) else BUY_BOMB_REMOTE:FireServer(name) end end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

-- ---------------------------------------------------------------------
--  2. GUI SYSTEM
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 260, 0, 420)
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
    btn.TextColor3 = Color3.fromRGB(220, 80, 80)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.BackgroundColor3 = on and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(45, 45, 45)
        btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(220, 80, 80)
        btn.Text = name .. (on and ": ON" or ": OFF")
        callback(on)
    end)
end

createToggle("Auto Buy Bombs", 45, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 90, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("No Ragdoll", 135, function(s) ProfileSettings.NoRagdollActive = s end)
createToggle("Infinite Multi-Jump", 180, function(s) ProfileSettings.MultiJumpActive = s end)

-- Slider Helper
local function createSlider(name, yPos, min, max, callback)
    local lbl = Instance.new("TextLabel", MainFrame)
    lbl.Size = UDim2.new(0.9, 0, 0, 20)
    lbl.Position = UDim2.new(0.05, 0, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = name .. ": 1.0x"
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    
    local track = Instance.new("Frame", MainFrame)
    track.Size = UDim2.new(0.9, 0, 0, 8)
    track.Position = UDim2.new(0.05, 0, 0, yPos + 20)
    track.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 4)
    
    local knob = Instance.new("TextButton", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, -7, 0.5, -7)
    knob.Text = ""
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    
    knob.MouseButton1Down:Connect(function()
        local conn
        conn = game:GetService("RunService").RenderStepped:Connect(function()
            local rel = math.clamp((Mouse.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            knob.Position = UDim2.new(rel, -7, 0.5, -7)
            local val = math.floor(((min + (rel * (max - min))) * 2) + 0.5) / 2
            lbl.Text = name .. ": " .. string.format("%.1f", val) .. (name == "Luck Boost" and "" or "x")
            callback(val)
        end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then conn:Disconnect() end end)
    end)
end

createSlider("Speed Multiplier", 240, 1.0, 3.0, function(v) 
    ProfileSettings.CurrentSpeedMultiplier = v
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16 * v
    end
end)

createSlider("Luck Boost", 300, 0, 100, function(v) 
    ProfileSettings.LuckBoostValue = v
    if LUCK_REMOTE then pcall(function() LUCK_REMOTE:FireServer(v) end) end
end)

UserInputService.InputBegan:Connect(function(i, gpe) if not gpe and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
