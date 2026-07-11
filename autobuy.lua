-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL (MODIFIED)
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Main State Flags
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
--  1. AUTOMATION LOOPS & REMOTES
-- ---------------------------------------------------------------------

local BUY_BOMB_REMOTE = nil
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage

if remotesFolder then
    BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
end

local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}

-- Auto Buy Loop
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

-- Instant Interaction
ProximityPromptService.PromptShown:Connect(function(prompt)
    if ProfileSettings.InstantInteractions then
        prompt.HoldDuration = 0
    end
end)

-- No Ragdoll Monitor
task.spawn(function()
    while true do
        task.wait(0.5)
        if ProfileSettings.NoRagdollActive and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
                end)
            end
        end
    end
end)

local function ManageCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        local expectedSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
        if math.abs(humanoid.WalkSpeed - expectedSpeed) > 1 then
            humanoid.WalkSpeed = expectedSpeed
        end
    end)
    humanoid.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
    
    humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            jumpCount = 0
        end
    end)
end

if LocalPlayer and LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end
if LocalPlayer then LocalPlayer.CharacterAdded:Connect(ManageCharacter) end

-- Multi-Jump
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == Enum.KeyCode.Space and ProfileSettings.MultiJumpActive then
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart then
            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
                if jumpCount < maxBonusJumps then
                    jumpCount = jumpCount + 1
                    rootPart.Velocity = Vector3.new(rootPart.Velocity.X, humanoid.JumpPower, rootPart.Velocity.Z)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------
--  2. GRAPHICAL USER INTERFACE
-- ---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 310)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

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

createToggle("Auto Buy Bombs", 55, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 105, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("No Ragdoll", 155, function(s) ProfileSettings.NoRagdollActive = s end)
createToggle("Infinite Multi-Jump", 205, function(s) ProfileSettings.MultiJumpActive = s end)

-- Speed Slider (Kept for functionality)
local SliderContainer = Instance.new("Frame", MainFrame)
SliderContainer.Size = UDim2.new(0.9, 0, 0, 45)
SliderContainer.Position = UDim2.new(0.05, 0, 0, 250)
SliderContainer.BackgroundTransparency = 1

local SliderLabel = Instance.new("TextLabel", SliderContainer)
SliderLabel.Size = UDim2.new(1, 0, 0, 20)
SliderLabel.Text = "Speed Multiplier: 1.0x"
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

local SliderTrack = Instance.new("Frame", SliderContainer)
SliderTrack.Size = UDim2.new(1, 0, 0, 6)
SliderTrack.Position = UDim2.new(0, 0, 0, 28)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

local SliderButton = Instance.new("TextButton", SliderTrack)
SliderButton.Size = UDim2.new(0, 14, 0, 14)
SliderButton.Position = UDim2.new(0, 0, 0.5, -7)
SliderButton.BackgroundColor3 = Color3.fromRGB(180, 180, 180)

local isDragging = false
SliderButton.MouseButton1Down:Connect(function() isDragging = true end)
UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement) then
        local trackWidth = SliderTrack.AbsoluteSize.X
        local relX = math.clamp((input.Position.X - SliderTrack.AbsolutePosition.X) / trackWidth, 0, 1)
        local snapValue = math.floor((1.0 + (relX * 4.0)) * 2 + 0.5) / 2
        
        SliderButton.Position = UDim2.new((snapValue - 1.0) / 4.0, -7, 0.5, -7)
        SliderLabel.Text = "Speed Multiplier: " .. string.format("%.1f", snapValue) .. "x"
        ProfileSettings.CurrentSpeedMultiplier = snapValue
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = 16 * snapValue
        end
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end
end)
