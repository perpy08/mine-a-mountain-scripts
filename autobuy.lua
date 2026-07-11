-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- Main State Flags
local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    MultiJumpActive = false,
    NoRagdollActive = false, -- New Flag
    CurrentSpeedMultiplier = 1.0
}

local maxBonusJumps = 10
local jumpCount = 0

-- ---------------------------------------------------------------------
--  1. AUTOMATION LOOPS & REMOTES
-- ---------------------------------------------------------------------

local BUY_BOMB_REMOTE = nil
local HOME_REMOTE = nil
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage

if remotesFolder then
    BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
    HOME_REMOTE = remotesFolder:FindFirstChild("BackHomeController")
end

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
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

ProximityPromptService.PromptShown:Connect(function(prompt)
    if ProfileSettings.InstantInteractions then
        prompt.HoldDuration = 0
    end
end)

local function ManageCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
    if not humanoid or not rootPart then return end
    
    -- Speed Management
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        local expectedSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
        if math.abs(humanoid.WalkSpeed - expectedSpeed) > 1 then
            humanoid.WalkSpeed = expectedSpeed
        end
    end)
    humanoid.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
    
    -- Anti-Ragdoll Logic
    humanoid.StateChanged:Connect(function(_, newState)
        if ProfileSettings.NoRagdollActive then
            if newState == Enum.HumanoidStateType.Physics or newState == Enum.HumanoidStateType.Ragdoll then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
        if newState == Enum.HumanoidStateType.Landed then
            jumpCount = 0
        end
    end)
end

if LocalPlayer and LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end
if LocalPlayer then LocalPlayer.CharacterAdded:Connect(ManageCharacter) end

-- ---------------------------------------------------------------------
--  2. GRAPHICAL USER INTERFACE
-- ---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 400) -- Increased height slightly
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local HeaderLabel = Instance.new("TextLabel")
HeaderLabel.Size = UDim2.new(1, 0, 0, 35)
HeaderLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HeaderLabel.Text = "Mine A Mountain"
HeaderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
HeaderLabel.Font = Enum.Font.SourceSansBold
HeaderLabel.TextSize = 14
HeaderLabel.Parent = MainFrame

Instance.new("UICorner", HeaderLabel).CornerRadius = UDim.new(0, 8)

local function createToggle(name, positionY, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0.9, 0, 0, 35)
    Button.Position = UDim2.new(0.05, 0, 0, positionY)
    Button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Button.Text = name .. ": OFF"
    Button.TextColor3 = Color3.fromRGB(220, 80, 80)
    Button.Parent = MainFrame
    Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 4)

    local toggled = false
    Button.MouseButton1Click:Connect(function()
        toggled = not toggled
        Button.BackgroundColor3 = toggled and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(45, 45, 45)
        Button.TextColor3 = toggled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(220, 80, 80)
        Button.Text = name .. (toggled and ": ON" or ": OFF")
        callback(toggled)
    end)
end

-- UI Setup
createToggle("Auto Buy Bombs", 55, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 100, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("Infinite Multi-Jump", 145, function(s) ProfileSettings.MultiJumpActive = s end)
createToggle("No Ragdoll", 190, function(s) ProfileSettings.NoRagdollActive = s end)

local TeleportButton = Instance.new("TextButton")
TeleportButton.Size = UDim2.new(0.9, 0, 0, 35)
TeleportButton.Position = UDim2.new(0.05, 0, 0, 240)
TeleportButton.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
TeleportButton.Text = "GO TO BASE"
TeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportButton.Parent = MainFrame
Instance.new("UICorner", TeleportButton).CornerRadius = UDim.new(0, 4)

TeleportButton.MouseButton1Click:Connect(function()
    if HOME_REMOTE then
        if HOME_REMOTE:IsA("RemoteFunction") then HOME_REMOTE:InvokeServer() else HOME_REMOTE:FireServer() end
    end
end)

-- Slider moved down to 295 to fit the new button
-- [Rest of the slider logic remains the same]
