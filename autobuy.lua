-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL (V7)
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
    CurrentSpeedMultiplier = 1.0
}

local maxBonusJumps = 10
local jumpCount = 0

-- ---------------------------------------------------------------------
--  1. REMOTES & UTILS
-- ---------------------------------------------------------------------
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage
local BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
local SELL_REMOTE = remotesFolder:FindFirstChild("Sell") or remotesFolder:FindFirstChild("SellCrystals")
local SPAWN_NAME = "SpawnLocation" -- Adjust if the spawn part has a different name

-- Auto Buy Loop
task.spawn(function()
    local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            for _, bombName in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function() if BUY_BOMB_REMOTE:IsA("RemoteFunction") then BUY_BOMB_REMOTE:InvokeServer(bombName) else BUY_BOMB_REMOTE:FireServer(bombName) end end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

-- Sell Function
local function SellCrystals()
    if SELL_REMOTE then
        pcall(function() if SELL_REMOTE:IsA("RemoteFunction") then SELL_REMOTE:InvokeServer() else SELL_REMOTE:FireServer() end end)
    end
end

-- Teleport to Spawn Function
local function TeleportToSpawn()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local spawnPart = workspace:FindFirstChild(SPAWN_NAME, true) or workspace:FindFirstChild("SpawnLocation", true)
        if spawnPart then
            char.HumanoidRootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
        end
    end
end

-- ---------------------------------------------------------------------
--  2. GUI & BUTTONS
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 240, 0, 400)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame, {CornerRadius = UDim.new(0, 8)})

-- Helper to create Toggle
local function createToggle(name, yPos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(220, 80, 80)
    btn.Font = Enum.Font.SourceSans
    Instance.new("UICorner", btn, {CornerRadius = UDim.new(0, 4)})
    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.BackgroundColor3 = on and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(45, 45, 45)
        btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(220, 80, 80)
        btn.Text = name .. (on and ": ON" or ": OFF")
        callback(on)
    end)
end

-- Helper to create Action Button
local function createButton(name, yPos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(80, 80, 150)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", btn, {CornerRadius = UDim.new(0, 4)})
    btn.MouseButton1Click:Connect(callback)
end

createToggle("Auto Buy Bombs", 55, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 100, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("Infinite Multi-Jump", 145, function(s) ProfileSettings.MultiJumpActive = s end)

createButton("SELL CRYSTALS", 200, SellCrystals)
createButton("TELEPORT TO SPAWN", 250, TeleportToSpawn)

-- Hotkey to toggle UI
UserInputService.InputBegan:Connect(function(i, gpe) if not gpe and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
