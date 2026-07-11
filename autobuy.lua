-- =====================================================================
--  MINE A MOUNTAIN: ADVANCED AUTOMATION PANEL
-- =====================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Main State Flags
local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    FastHitting = false,
    CurrentSpeedMultiplier = 1.0
}

-- ---------------------------------------------------------------------
--  1. AUTOMATION FUNCTIONAL LOOPS
-- ---------------------------------------------------------------------

-- Safe Remote Discovery
local BUY_BOMB_REMOTE = nil
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5) or ReplicatedStorage:WaitForChild("Events", 5)

if remotesFolder then
    BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
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

-- Absolute Instant Mining (Forces Hold Duration to Zero)
ProximityPromptService.PromptShown:Connect(function(prompt)
    if ProfileSettings.InstantInteractions then
        prompt.HoldDuration = 0
    end
end)

-- Extreme Fast Hitting Engine (Bypasses tool animation delays completely)
task.spawn(function()
    while true do
        if ProfileSettings.FastHitting then
            pcall(function()
                local character = LocalPlayer.Character
                if character then
                    local equippedTool = character:FindFirstChildOfClass("Tool")
                    if equippedTool then
                        equippedTool:Activate()
                    end
                end
            end)
            task.wait(0.1) -- Rapid fire tool updates directly to server
        else
            task.wait(0.5)
        end
    end
end)

-- Anti-Reset Humanoid Speed Enforcer
local function ManageSpeed(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    -- Force speed instantly whenever the game attempts to override it
    local speedConnection
    speedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        local expectedSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
        if math.abs(humanoid.WalkSpeed - expectedSpeed) > 1 then
            humanoid.WalkSpeed = expectedSpeed
        end
    end)
    
    -- Apply initially
    humanoid.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
    
    -- Cleanup on death/respawn
    humanoid.Died:Connect(function()
        if speedConnection then speedConnection:Disconnect() end
    end)
end

if LocalPlayer.Character then ManageSpeed(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(ManageSpeed)

-- ---------------------------------------------------------------------
--  2. GRAPHICAL USER INTERFACE WITH UPDATED 5X SLIDER
-- ---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false

local success, err = pcall(function() ScreenGui.Parent = CoreGui end)
if not success then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Balanced Main Frame Window
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 265)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 8)
FrameCorner.Parent = MainFrame

-- Header
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

-- Toggle UI Helper Function
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

-- Render Structural Standard Toggles
createToggle("Auto Buy Bombs", 55, function(state)
    ProfileSettings.AutoBuyActive = state
end)

createToggle("Instant E-Mining", 105, function(state)
    ProfileSettings.InstantInteractions = state
end)

createToggle("Fast Crystal Hitting", 155, function(state)
    ProfileSettings.FastHitting = state
end)

-- ---------------------------------------------------------------------
--  3. EXPANDED SLIDER ELEMENT (SPEED MULTIPLIER UP TO 5.0x)
-- ---------------------------------------------------------------------

local SliderContainer = Instance.new("Frame")
SliderContainer.Size = UDim2.new(0.9, 0, 0, 45)
SliderContainer.Position = UDim2.new(0.05, 0, 0, 205)
SliderContainer.BackgroundTransparency = 1
SliderContainer.Parent = MainFrame

local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(1, 0, 0, 20)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = "Speed Multiplier: 1.0x"
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SliderLabel.Font = Enum.Font.SourceSans
SliderLabel.TextSize = 13
SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
SliderLabel.Parent = SliderContainer

local SliderTrack = Instance.new("Frame")
SliderTrack.Size = UDim2.new(1, 0, 0, 6)
SliderTrack.Position = UDim2.new(0, 0, 0, 28)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
SliderTrack.Parent = SliderContainer

local SliderTrackCorner = Instance.new("UICorner")
SliderTrackCorner.CornerRadius = UDim.new(0, 3)
SliderTrackCorner.Parent = SliderTrack

local SliderButton = Instance.new("TextButton")
SliderButton.Size = UDim2.new(0, 14, 0, 14)
SliderButton.Position = UDim2.new(0, 0, 0.5, -7)
SliderButton.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
SliderButton.Text = ""
SliderButton.Parent = SliderTrack

local SliderButtonCorner = Instance.new("UICorner")
SliderButtonCorner.CornerRadius = UDim.new(1, 0)
SliderButtonCorner.Parent = SliderButton

local isDragging = false

local function updateSlider(input)
    local trackWidth = SliderTrack.AbsoluteSize.X
    local mouseX = input.Position.X
    local relativeX = mouseX - SliderTrack.AbsolutePosition.X
    local percentage = math.clamp(relativeX / trackWidth, 0, 1)
    
    -- Maps linear percentage dynamically across range [1.0 -> 5.0]
    local rawValue = 1.0 + (percentage * 4.0)
    
    -- Snap checkpoints by steps of 0.5 (1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0)
    local snapValue = math.floor((rawValue * 2) + 0.5) / 2
    local finalPercentage = (snapValue - 1.0) / 4.0
    
    SliderButton.Position = UDim2.new(finalPercentage, -7, 0.5, -7)
    SliderLabel.Text = "Speed Multiplier: " .. string.format("%.1f", snapValue) .. "x"
    ProfileSettings.CurrentSpeedMultiplier = snapValue
    
    -- Instantly push configuration directly to current Humanoid physical frame
    pcall(function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16 * snapValue
        end
    end)
end

SliderButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

-- ---------------------------------------------------------------------
--  4. USER INPUT WINDOW ACCESSIBILITY LAYER
-- ---------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)
