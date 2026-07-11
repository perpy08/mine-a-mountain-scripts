-- =====================================================================
--  MINE A MOUNTAIN: DYNAMIC SMART HUB
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
    PullCount = 10,
    PullRadius = 50
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
    
    -- Updated matching to look for your newly discovered console keywords
    MINE_REMOTE = remotesFolder:FindFirstChild("CrystalMining") 
        or remotesFolder:FindFirstChild("CrystalMiningController") 
        or remotesFolder:FindFirstChild("Mine") 
        or remotesFolder:FindFirstChild("HitCrystal")
        
    LUCK_REMOTE = remotesFolder:FindFirstChild("CrystalLuck") 
        or remotesFolder:FindFirstChild("CrystalBoost") 
        or remotesFolder:FindFirstChild("LuckRemote")
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

task.spawn(function()
    while true do
        if ProfileSettings.FastHitting and Mouse then
            pcall(function()
                local target = Mouse.Target
                -- Scan for name matching using your found tags
                if target and (target.Name:lower():find("crystal") or target.Name:lower():find("lod") or (target.Parent and target.Parent.Name:lower():find("crystal"))) then
                    local character = LocalPlayer.Character
                    if character then
                        local equippedTool = character:FindFirstChildOfClass("Tool")
                        if equippedTool then
                            if MINE_REMOTE then
                                if MINE_REMOTE:IsA("RemoteEvent") then
                                    MINE_REMOTE:FireServer()
                                elseif MINE_REMOTE:IsA("RemoteFunction") then
                                    MINE_REMOTE:InvokeServer()
                                end
                            end
                            equippedTool:Activate()
                        end
                    end
                end
            end)
            task.wait(0.05)
        else
            task.wait(0.5)
        end
    end
end)

-- ---------------------------------------------------------------------
--  2. CRYSTAL MAGNET ENGINE (MANUAL TRIGGER)
-- ---------------------------------------------------------------------
local function TriggerCrystalMagnet()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local pulled = 0
    local targetRarity = ProfileSettings.SelectedRarity:lower()

    for _, obj in ipairs(workspace:GetDescendants()) do
        if pulled >= ProfileSettings.PullCount then break end

        local isCrystal = obj:IsA("BasePart") and (obj.Name:lower():find("crystal") or obj.Name:lower():find("lod") or (obj.Parent and obj.Parent.Name:lower():find("crystal")))
        
        if isCrystal and obj.CanCollide == true then 
            local distance = (obj.Position - rootPart.Position).Magnitude
            if distance <= ProfileSettings.PullRadius then
                local matchesRarity = false
                if targetRarity == "all" then
                    matchesRarity = true
                else
                    if obj.Name:lower():find(targetRarity) or (obj.Parent and obj.Parent.Name:lower():find(targetRarity)) then
                        matchesRarity = true
                    end
                end

                if matchesRarity then
                    pulled = pulled + 1
                    pcall(function()
                        obj.CFrame = rootPart.CFrame * CFrame.new(0, -2, -2)
                    end)
                end
            end
        end
    end
end

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
    
    local stateConnection
    stateConnection = humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            jumpCount = 0
        end
    end)
    
    humanoid.Died:Connect(function()
        if speedConnection then speedConnection:Disconnect() end
        if stateConnection then stateConnection:Disconnect() end
    end)
end

if LocalPlayer and LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end
if LocalPlayer then LocalPlayer.CharacterAdded:Connect(ManageCharacter) end

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
--  3. GRAPHICAL USER INTERFACE (DYNAMIC AUTO-SISING)
-- ---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 360) -- Dynamic base start height
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 8)
FrameCorner.Parent = MainFrame

local HeaderLabel = Instance.new("TextLabel")
HeaderLabel.Size = UDim2.new(1, 0, 0, 35)
HeaderLabel.BackgroundColor3 = Color3.fromRGB(33, 33, 33)
HeaderLabel.Text = "Mine A Mountain Hub"
HeaderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
HeaderLabel.Font = Enum.Font.SourceSansBold
HeaderLabel.TextSize = 14
HeaderLabel.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = HeaderLabel

-- Base UI Element Positioning Containers
local BottomSlidersContainer = Instance.new("Frame")
BottomSlidersContainer.Size = UDim2.new(0.9, 0, 0, 100)
BottomSlidersContainer.Position = UDim2.new(0.05, 0, 0, 225) -- Shifts down on magnet activation
BottomSlidersContainer.BackgroundTransparency = 1
BottomSlidersContainer.Parent = MainFrame

local function createToggle(name, positionY, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0.9, 0, 0, 30)
    Button.Position = UDim2.new(0.05, 0, 0, positionY)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Button.Text = name .. ": OFF"
    Button.TextColor3 = Color3.fromRGB(220, 80, 80)
    Button.Font = Enum.Font.SourceSans
    Button.TextSize = 13
    Button.Parent = MainFrame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Button

    local toggled = false
    Button.MouseButton1Click:Connect(function()
        toggled = not toggled
        if toggled then
            Button.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
            Button.TextColor3 = Color3.fromRGB(255, 255, 255)
            Button.Text = name .. ": ON"
        else
            Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            Button.TextColor3 = Color3.fromRGB(220, 80, 80)
            Button.Text = name .. ": OFF"
        end
        callback(toggled)
    end)
    return Button
end

createToggle("Auto Buy Bombs", 45, function(state) ProfileSettings.AutoBuyActive = state end)
createToggle("Instant E-Mining", 80, function(state) ProfileSettings.InstantInteractions = state end)
createToggle("Smart Fast Hitting", 115, function(state) ProfileSettings.FastHitting = state end)
createToggle("Infinite Multi-Jump", 150, function(state) ProfileSettings.MultiJumpActive = state end)

-- ---------------------------------------------------------------------
--  4. MAGNET PANEL EXPANSION SYSTEM
-- ---------------------------------------------------------------------
local MagnetContainer = Instance.new("Frame")
MagnetContainer.Size = UDim2.new(0.9, 0, 0, 160)
MagnetContainer.Position = UDim2.new(0.05, 0, 0, 225)
MagnetContainer.BackgroundTransparency = 1
MagnetContainer.Visible = false
MagnetContainer.Parent = MainFrame

-- Rarity Dropdown Elements
local DropdownButton = Instance.new("TextButton")
DropdownButton.Size = UDim2.new(1, 0, 0, 25)
DropdownButton.Position = UDim2.new(0, 0, 0, 0)
DropdownButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
DropdownButton.Text = "Rarity: All"
DropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DropdownButton.Font = Enum.Font.SourceSans
DropdownButton.TextSize = 13
DropdownButton.Parent = MagnetContainer

local DropdownList = Instance.new("Frame")
DropdownList.Size = UDim2.new(1, 0, 0, 120)
DropdownList.Position = UDim2.new(0, 0, 0, 27)
DropdownList.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
DropdownList.Visible = false
DropdownList.ZIndex = 5
DropdownList.Parent = MagnetContainer

local rarities = {"All", "Common", "Rare", "Epic", "Legendary", "Mythic"}
for i, rarityName in ipairs(rarities) do
    local RarityBtn = Instance.new("TextButton")
    RarityBtn.Size = UDim2.new(1, 0, 0, 20)
    RarityBtn.Position = UDim2.new(0, 0, 0, (i-1)*20)
    RarityBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    RarityBtn.Text = rarityName
    RarityBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    RarityBtn.Font = Enum.Font.SourceSans
    RarityBtn.TextSize = 12
    RarityBtn.ZIndex = 6
    RarityBtn.Parent = DropdownList

    RarityBtn.MouseButton1Click:Connect(function()
        ProfileSettings.SelectedRarity = rarityName
        DropdownButton.Text = "Rarity: " .. rarityName
        DropdownList.Visible = false
    end)
end

DropdownButton.MouseButton1Click:Connect(function()
    DropdownList.Visible = not DropdownList.Visible
end)

-- Limit Number Input Box
local InputLabel = Instance.new("TextLabel")
InputLabel.Size = UDim2.new(0.6, 0, 0, 25)
InputLabel.Position = UDim2.new(0, 0, 0, 35)
InputLabel.BackgroundTransparency = 1
InputLabel.Text = "Pull Count Limit:"
InputLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
InputLabel.Font = Enum.Font.SourceSans
InputLabel.TextSize = 13
InputLabel.TextXAlignment = Enum.TextXAlignment.Left
InputLabel.Parent = MagnetContainer

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(0.35, 0, 0, 22)
TextBox.Position = UDim2.new(0.65, 0, 0, 36)
TextBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
TextBox.Text = "10"
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.Font = Enum.Font.SourceSans
TextBox.TextSize = 13
TextBox.Parent = MagnetContainer

TextBox.FocusLost:Connect(function()
    local num = tonumber(TextBox.Text)
    if num then
        ProfileSettings.PullCount = math.clamp(math.floor(num), 1, 100)
        TextBox.Text = tostring(ProfileSettings.PullCount)
    else
        TextBox.Text = tostring(ProfileSettings.PullCount)
    end
end)

-- Magnet Radius Slider Track
local MagSliderTrack = Instance.new("Frame")
MagSliderTrack.Size = UDim2.new(1, 0, 0, 6)
MagSliderTrack.Position = UDim2.new(0, 0, 0, 85)
MagSliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
MagSliderTrack.Parent = MagnetContainer

local MagSliderLabel = Instance.new("TextLabel")
MagSliderLabel.Size = UDim2.new(1, 0, 0, 15)
MagSliderLabel.Position = UDim2.new(0, 0, 0, 65)
MagSliderLabel.BackgroundTransparency = 1
MagSliderLabel.Text = "Scan Radius: 50 studs"
MagSliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
MagSliderLabel.Font = Enum.Font.SourceSans
MagSliderLabel.TextSize = 12
MagSliderLabel.TextXAlignment = Enum.TextXAlignment.Left
MagSliderLabel.Parent = MagnetContainer

local MagSliderBtn = Instance.new("TextButton")
MagSliderBtn.Size = UDim2.new(0, 12, 0, 12)
MagSliderBtn.Position = UDim2.new(0.2, -6, 0.5, -6)
MagSliderBtn.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
MagSliderBtn.Text = ""
MagSliderBtn.Parent = MagSliderTrack

local magDragging = false
MagSliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        magDragging = true
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if magDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local relativeX = input.Position.X - MagSliderTrack.AbsolutePosition.X
        local pct = math.clamp(relativeX / MagSliderTrack.AbsoluteSize.X, 0, 1)
        local radiusVal = math.floor(10 + (pct * 240))
        
        MagSliderBtn.Position = UDim2.new(pct, -6, 0.5, -6)
        MagSliderLabel.Text = "Scan Radius: " .. radiusVal .. " studs"
        ProfileSettings.PullRadius = radiusVal
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        magDragging = false
    end
end)

local PullActionBtn = Instance.new("TextButton")
PullActionBtn.Size = UDim2.new(1, 0, 0, 30)
PullActionBtn.Position = UDim2.new(0, 0, 0, 110)
PullActionBtn.BackgroundColor3 = Color3.fromRGB(70, 50, 100)
PullActionBtn.Text = "✨ PULL CRYSTALS ✨"
PullActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PullActionBtn.Font = Enum.Font.SourceSansBold
PullActionBtn.TextSize = 13
PullActionBtn.Parent = MagnetContainer

local PullCorner = Instance.new("UICorner")
PullCorner.CornerRadius = UDim.new(0, 4)
PullCorner.Parent = PullActionBtn

PullActionBtn.MouseButton1Click:Connect(function()
    TriggerCrystalMagnet()
end)

-- Dynamic UI Height Sizing Controller Logic
createToggle("Crystal Magnet System", 185, function(state)
    ProfileSettings.MagnetActive = state
    MagnetContainer.Visible = state
    if state then
        MainFrame.Size = UDim2.new(0, 250, 0, 520)
        BottomSlidersContainer.Position = UDim2.new(0.05, 0, 0, 395)
    else
        MainFrame.Size = UDim2.new(0, 250, 0, 360)
        BottomSlidersContainer.Position = UDim2.new(0.05, 0, 0, 225)
    end
end)

-- ---------------------------------------------------------------------
--  5. WALK SPEED MULTIPLIER SLIDER
-- ---------------------------------------------------------------------

local SliderContainer = Instance.new("Frame")
SliderContainer.Size = UDim2.new(1, 0, 0, 45)
SliderContainer.Position = UDim2.new(0, 0, 0, 0)
SliderContainer.BackgroundTransparency = 1
SliderContainer.Parent = BottomSlidersContainer

local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(1, 0, 0, 15)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = "WalkSpeed Multiplier: 1.0x"
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SliderLabel.Font = Enum.Font.SourceSans
SliderLabel.TextSize = 12
SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
SliderLabel.Parent = SliderContainer

local SliderTrack = Instance.new("Frame")
SliderTrack.Size = UDim2.new(1, 0, 0, 6)
SliderTrack.Position = UDim2.new(0, 0, 0, 22)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
SliderTrack.Parent = SliderContainer

local SliderButton = Instance.new("TextButton")
SliderButton.Size = UDim2.new(0, 14, 0, 14)
SliderButton.Position = UDim2.new(0, 0, 0.5, -7)
SliderButton.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
SliderButton.Text = ""
SliderButton.Parent = SliderTrack

local isDragging = false
SliderButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local pct = math.clamp((input.Position.X - SliderTrack.AbsolutePosition.X) / SliderTrack.AbsoluteSize.X, 0, 1)
        local snapValue = math.floor(((1.0 + (pct * 4.0)) * 2) + 0.5) / 2
        
        SliderButton.Position = UDim2.new((snapValue - 1.0) / 4.0, -7, 0.5, -7)
        SliderLabel.Text = "WalkSpeed Multiplier: " .. string.format("%.1f", snapValue) .. "x"
        ProfileSettings.CurrentSpeedMultiplier = snapValue
        
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16 * snapValue
            end
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

-- ---------------------------------------------------------------------
--  6. NEW OPTIMIZATION: CRYSTAL LUCK BOOST SLIDER (0 - 100)
-- ---------------------------------------------------------------------

local BoostContainer = Instance.new("Frame")
BoostContainer.Size = UDim2.new(1, 0, 0, 45)
BoostContainer.Position = UDim2.new(0, 0, 0, 50)
BoostContainer.BackgroundTransparency = 1
BoostContainer.Parent = BottomSlidersContainer

local BoostLabel = Instance.new("TextLabel")
BoostLabel.Size = UDim2.new(1, 0, 0, 15)
BoostLabel.BackgroundTransparency = 1
BoostLabel.Text = "Crystal Luck Boost: 0"
BoostLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
BoostLabel.Font = Enum.Font.SourceSans
BoostLabel.TextSize = 12
BoostLabel.TextXAlignment = Enum.TextXAlignment.Left
BoostLabel.Parent = BoostContainer

local BoostTrack = Instance.new("Frame")
BoostTrack.Size = UDim2.new(1, 0, 0, 6)
BoostTrack.Position = UDim2.new(0, 0, 0, 22)
BoostTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
BoostTrack.Parent = BoostContainer

local BoostButton = Instance.new("TextButton")
BoostButton.Size = UDim2.new(0, 14, 0, 14)
BoostButton.Position = UDim2.new(0, -7, 0.5, -7)
BoostButton.BackgroundColor3 = Color3.fromRGB(150, 100, 200) -- Unique Purple Accent Color
BoostButton.Text = ""
BoostButton.Parent = BoostTrack

local boostDragging = false
BoostButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        boostDragging = true
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if boostDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local pct = math.clamp((input.Position.X - BoostTrack.AbsolutePosition.X) / BoostTrack.AbsoluteSize.X, 0, 1)
        local boostValue = math.floor(pct * 100)
        
        BoostButton.Position = UDim2.new(pct, -7, 0.5, -7)
        BoostLabel.Text = "Crystal Luck Boost: " .. tostring(boostValue)
        ProfileSettings.CrystalBoostValue = boostValue
        
        -- Safe execution fire to the game framework if remote hooks match
        if LUCK_REMOTE then
            pcall(function()
                if LUCK_REMOTE:IsA("RemoteEvent") then
                    LUCK_REMOTE:FireServer(boostValue)
                elseif LUCK_REMOTE:IsA("RemoteFunction") then
                    LUCK_REMOTE:InvokeServer(boostValue)
                end
            end)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        boostDragging = false
    end
end)

-- Visibility Layer Toggle Hotkey (Insert Key)
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)
