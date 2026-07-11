-- =====================================================================
--  MINE A MOUNTAIN: REFINED HUB
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    MultiJumpActive = false,
    CurrentSpeedMultiplier = 1.0,
    CrystalBoostValue = 0
}

local maxBonusJumps = 10
local jumpCount = 0

-- Setup Remotes
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage
local BUY_BOMB_REMOTE = remotes:FindFirstChild("BuyBomb") or remotes:FindFirstChild("PurchaseBomb")
local LUCK_REMOTE = remotes:FindFirstChild("CrystalLuck") or remotes:FindFirstChild("CrystalBoost") or remotes:FindFirstChild("LuckRemote")

-- ---------------------------------------------------------------------
--  GUI SYSTEM
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 260, 0, 300)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local function createToggle(name, yPos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.BackgroundColor3 = on and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(50, 50, 50)
        btn.Text = name .. (on and ": ON" or ": OFF")
        callback(on)
    end)
end

createToggle("Auto Buy Bombs", 10, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 55, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("Multi-Jump", 100, function(s) ProfileSettings.MultiJumpActive = s end)

-- Slider Helper
local function createSlider(name, yPos, min, max, callback)
    local label = Instance.new("TextLabel", MainFrame)
    label.Size = UDim2.new(0.9, 0, 0, 20)
    label.Position = UDim2.new(0.05, 0, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = name .. ": "
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    
    local track = Instance.new("Frame", MainFrame)
    track.Size = UDim2.new(0.9, 0, 0, 8)
    track.Position = UDim2.new(0.05, 0, 0, yPos + 20)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    
    local knob = Instance.new("TextButton", track)
    knob.Size = UDim2.new(0, 15, 0, 15)
    knob.Position = UDim2.new(0, -7, 0.5, -7)
    knob.Text = ""
    
    knob.MouseButton1Down:Connect(function()
        local conn
        conn = game:GetService("RunService").RenderStepped:Connect(function()
            local mouseX = game:GetService("UserInputService"):GetMouseLocation().X
            local relX = math.clamp((mouseX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            knob.Position = UDim2.new(relX, -7, 0.5, -7)
            local val = math.floor(min + (relX * (max - min)))
            label.Text = name .. ": " .. val
            callback(val)
        end)
        game:GetService("UserInputService").InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then conn:Disconnect() end
        end)
    end)
end

createSlider("WalkSpeed", 150, 16, 80, function(v) 
    ProfileSettings.CurrentSpeedMultiplier = v/16
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = v
    end
end)

createSlider("Luck Boost", 210, 0, 100, function(v) 
    ProfileSettings.CrystalBoostValue = v
    if LUCK_REMOTE then pcall(function() LUCK_REMOTE:FireServer(v) end) end
end)

-- ---------------------------------------------------------------------
--  LOGIC
-- ---------------------------------------------------------------------
task.spawn(function()
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            pcall(function() BUY_BOMB_REMOTE:FireServer("Classic Bomb") end)
        end
        task.wait(3)
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end
end)
