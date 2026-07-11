-- =====================================================================
--  MINE A MOUNTAIN: STABLE INTEGRATED HUB
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

-- Main State Flags & Configurations
local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    FastHitting = false,
    MultiJumpActive = false,
    CurrentSpeedMultiplier = 1.0,
    CrystalBoostValue = 0,
    
    -- Magnet Settings
    MagnetActive = false,
    SelectedRarity = "All",
    PullCount = 50,
    PullRadius = 1000
}

local maxBonusJumps = 10
local jumpCount = 0

-- ---------------------------------------------------------------------
--  1. AUTOMATION ENGINE & REMOTES
-- ---------------------------------------------------------------------

local BUY_BOMB_REMOTE = nil
local MINE_REMOTE = nil
local LUCK_REMOTE = nil

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage

if remotesFolder then
    BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
    MINE_REMOTE = remotesFolder:FindFirstChild("CrystalMining") or remotesFolder:FindFirstChild("CrystalMiningController") or remotesFolder:FindFirstChild("Mine") or remotesFolder:FindFirstChild("HitCrystal")
    LUCK_REMOTE = remotesFolder:FindFirstChild("CrystalLuck") or remotesFolder:FindFirstChild("CrystalBoost") or remotesFolder:FindFirstChild("LuckRemote")
end

local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}

-- Auto Buy Loop
task.spawn(function()
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            for _, bombName in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function()
                    if BUY_BOMB_REMOTE:IsA("RemoteFunction") then BUY_BOMB_REMOTE:InvokeServer(bombName) else BUY_BOMB_REMOTE:FireServer(bombName) end
                end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

-- Auto Magnet Loop
task.spawn(function()
    while true do
        if ProfileSettings.MagnetActive then
            pcall(function()
                local character = LocalPlayer.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local pulled = 0
                    local target = ProfileSettings.SelectedRarity:lower()
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if pulled >= ProfileSettings.PullCount then break end
                        if obj:IsA("BasePart") then
                            local name = obj.Name:lower()
                            local parentName = (obj.Parent and obj.Parent.Name:lower()) or ""
                            if (name:find("crystal") or name:find("lod") or parentName:find("crystal")) then
                                local dist = (obj.Position - rootPart.Position).Magnitude
                                if dist <= ProfileSettings.PullRadius then
                                    local matches = (target == "all" or name:find(target) or parentName:find(target))
                                    if matches then
                                        pulled = pulled + 1
                                        obj.CFrame = rootPart.CFrame * CFrame.new(0, -2, -2)
                                    end
                                end
                            end
                        end
                        task.wait(0.001)
                    end
                end
            end)
        end
        task.wait(1)
    end
end)

-- ---------------------------------------------------------------------
--  2. GUI & INTERACTION
-- ---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 250, 0, 360)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
MainFrame.Active = true
MainFrame.Draggable = true 

-- [Magnet Logic Slider] 
-- Inside your existing GUI section where you handle the Radius Slider:
-- Update the pct calculation math to: 
-- local radiusVal = math.floor(10 + (pct * 990)) 
-- This ensures the slider hits 1000 studs at the end.

-- Toggle for Magnet System
local function createToggle(name, positionY, callback)
    local Button = Instance.new("TextButton", MainFrame)
    Button.Size = UDim2.new(0.9, 0, 0, 30)
    Button.Position = UDim2.new(0.05, 0, 0, positionY)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Button.Text = name .. ": OFF"
    Button.TextColor3 = Color3.fromRGB(220, 80, 80)
    Button.MouseButton1Click:Connect(function()
        local state = not (Button.BackgroundColor3 == Color3.fromRGB(50, 100, 50))
        Button.BackgroundColor3 = state and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(40, 40, 40)
        Button.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(220, 80, 80)
        Button.Text = name .. (state and ": ON" or ": OFF")
        callback(state)
    end)
end

createToggle("Crystal Magnet System", 185, function(state) ProfileSettings.MagnetActive = state end)
-- Add other buttons here as per your original file structure...

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end
end)
