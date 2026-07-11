-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Main State Flags
local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    MultiJumpActive = false,
    NoRagdollActive = false,
    NoDamageActive = false,
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

RunService.Heartbeat:Connect(function()
    if ProfileSettings.NoDamageActive then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end
end)

local function ManageCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
    if not humanoid or not rootPart then return end
    
    local speedConnection
    speedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        local expectedSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
        if math.abs(humanoid.WalkSpeed - expectedSpeed) > 1 then
            humanoid.WalkSpeed = expectedSpeed
        end
    end)
    humanoid.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier

    local platformConnection
    platformConnection = humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if ProfileSettings.NoRagdollActive and humanoid.PlatformStand then
            humanoid.PlatformStand = false
        end
    end)
    
    local stateConnection
    stateConnection = humanoid.StateChanged:Connect(function(_, newState)
        if ProfileSettings.NoRagdollActive and (newState == Enum.HumanoidStateType.Physics or newState == Enum.HumanoidStateType.Ragdoll or newState == Enum.HumanoidStateType.FallingDown) then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if newState == Enum.HumanoidStateType.Landed then
            jumpCount = 0
        end
    end)
    
    humanoid.Died:Connect(function()
        if speedConnection then speedConnection:Disconnect() end
        if platformConnection then platformConnection:Disconnect() end
        if stateConnection then stateConnection:Disconnect() end
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
MainFrame.Size = UDim2.new(0, 240, 0, 440)
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
    Button.Font = Enum.Font.SourceSans
    Button.TextSize = 14
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
createToggle("Infinite Multi-Jump", 155, function(s) ProfileSettings.MultiJumpActive = s end)
createToggle("No Ragdoll", 205, function(s) ProfileSettings.NoRagdollActive = s end)
createToggle("No Damage", 255, function(s) ProfileSettings.NoDamageActive = s end)

local TeleportButton = Instance.new("TextButton")
TeleportButton.Size = UDim2.new(0.9, 0, 0, 35)
TeleportButton.Position = UDim2.new(0.05, 0, 0, 305)
TeleportButton.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
TeleportButton.Text = "TELEPORT TO SPAWN"
TeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportButton.Parent = MainFrame
Instance.new("UICorner", TeleportButton).CornerRadius = UDim.new(0, 4)
TeleportButton.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local spawn = workspace:FindFirstChild("SpawnLocation", true)
        if spawn then
            TweenService:Create(char.HumanoidRootPart, TweenInfo.new(0.5), {CFrame = spawn.CFrame + Vector3.new(0, 3, 0)}):Play()
        end
    end
end)

-- ---------------------------------------------------------------------
--  3. SLIDER ELEMENT (RESTORED)
-- ---------------------------------------------------------------------

local SliderContainer = Instance.new("Frame")
SliderContainer.Size = UDim2.new(0.9, 0, 0, 45)
SliderContainer.Position = UDim2.new(0.05, 0, 0, 360)
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
Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(0, 3)

local SliderButton = Instance.new("TextButton")
SliderButton.Size = UDim2.new(0, 14, 0, 14)
SliderButton.Position = UDim2.new(0, 0, 0.5, -7)
SliderButton.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
SliderButton.Text = ""
SliderButton.Parent = SliderTrack
Instance.new("UICorner", SliderButton).CornerRadius = UDim.new(1, 0)

local isDragging = false

local function updateSlider(input)
    local trackWidth = SliderTrack.AbsoluteSize.X
    local mouseX = input.Position.X
    local relativeX = mouseX - SliderTrack.AbsolutePosition.X
    local percentage = math.clamp(relativeX / trackWidth, 0, 1)
    
    local rawValue = 1.0 + (percentage * 4.0)
    local snapValue = math.floor((rawValue * 2) + 0.5) / 2
    local finalPercentage = (snapValue - 1.0) / 4.0
    
    SliderButton.Position = UDim2.new(finalPercentage, -7, 0.5, -7)
    SliderLabel.Text = "Speed Multiplier: " .. string.format("%.1f", snapValue) .. "x"
    ProfileSettings.CurrentSpeedMultiplier = snapValue
    
    pcall(function()
        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16 * snapValue
        end
    end)
end

SliderButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDragging = true end
end)
UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateSlider(input) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDragging = false end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end
end)
