-- =====================================================================
--  MINE A MOUNTAIN: STREAMLINED AUTOMATION PANEL
-- =====================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

-- Main State Flags
local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false
}

-- ---------------------------------------------------------------------
--  1. AUTOMATION FUNCTIONAL LOOPS
-- ---------------------------------------------------------------------

-- Auto Buy Logic
local BUY_BOMB_REMOTE = ReplicatedStorage:WaitForChild("Remotes", 5):FindFirstChild("BuyBomb") or ReplicatedStorage:WaitForChild("Events", 5):FindFirstChild("PurchaseBomb")
local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}

task.spawn(function()
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            for _, bombName in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function()
                    if BUY_BOMB_REMOTE:IsA("RemoteFunction") then
                        BUY_BOMB_REMOTE:InvokeServer(bombName)
                    else
                        BUY_BOMB_REMOTE:FireServer(bombName)
                    end
                end)
                task.wait(0.4) -- Small safety delay between purchases
            end
        end
        task.wait(3) -- Time between total inventory check sweeps
    end
end)

-- Fast Mining Logic (Triggers the hold interaction instantly)
ProximityPromptService.PromptShown:Connect(function(prompt)
    if ProfileSettings.InstantInteractions then
        task.wait()
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration)
        prompt:InputHoldEnd()
    end
end)

-- ---------------------------------------------------------------------
--  2. MINIMALIST GRAPHICAL USER INTERFACE
-- ---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false

-- Safe attachment to avoid UI wiping on respawn
local success, err = pcall(function() ScreenGui.Parent = CoreGui end)
if not success then ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

-- Compact Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 160)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true -- Left-click and drag the panel anywhere on your screen
MainFrame.Parent = ScreenGui

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 8)
FrameCorner.Parent = MainFrame

-- Top Title Bar
local HeaderLabel = Instance.new("TextLabel")
HeaderLabel.Size = UDim2.new(1, 0, 0, 35)
HeaderLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HeaderLabel.Text = "Mine A Mountain"
HeaderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
HeaderLabel.Font = Enum.Font.SourceSansBold
HeaderLabel.TextSize = 14
HeaderLabel.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = HeaderLabel

-- Toggle Creation Helper
local function createToggle(name, positionY, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0.9, 0, 0, 35)
    Button.Position = UDim2.new(0.05, 0, 0, positionY)
    Button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Button.Text = name .. ": OFF"
    Button.TextColor3 = Color3.fromRGB(220, 80, 80)
    Button.Font = Enum.Font.SourceSans
    Button.TextSize = 14
    Button.Parent = MainFrame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Button

    local toggled = false
    Button.MouseButton1Click:Connect(function()
        toggled = not toggled
        if toggled then
            Button.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
            Button.TextColor3 = Color3.fromRGB(255, 255, 255)
            Button.Text = name .. ": ON"
        else
            Button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            Button.TextColor3 = Color3.fromRGB(220, 80, 80)
            Button.Text = name .. ": OFF"
        end
        callback(toggled)
    end)
end

-- Render the two required options explicitly
createToggle("Auto Buy Bombs", 55, function(state)
    ProfileSettings.AutoBuyActive = state
end)

createToggle("Instant E-Mining Prompt", 105, function(state)
    ProfileSettings.InstantInteractions = state
end)
