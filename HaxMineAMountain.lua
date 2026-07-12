-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL + LAG FX MERGE
--  Combines autobuy.lua and glitch.lua into a single script
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Main State Flags (extended with Lag FX)
local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    MultiJumpActive = false,
    NoRagdollActive = false,
    NoDamageActive = false,
    PlayerESPActive = false,
    CurrentSpeedMultiplier = 1.0,
    LagFXActive = false,    -- new flag from glitch.lua
    LagFPS = 3              -- how "laggy" the effect is; lower = more lag
}

local maxBonusJumps = 10
local jumpCount = 0
local spaceHeld = false  -- Track if space is currently held down

-- internal helper mapping for current speed (keeps parity with ProfileSettings)
local function getCurrentSpeed()
    return ProfileSettings.CurrentSpeedMultiplier or 1.0
end

-- ---------------------------------------------------------------------
--  1. ESP LOGIC
-- ---------------------------------------------------------------------

local function createESP(player)
    if player == LocalPlayer then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "PlayerHighlight"
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.Enabled = false

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerLabel"
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false

    local nameLabel = Instance.new("TextLabel", billboard)
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextStrokeTransparency = 0

    local function setupChar(char)
        highlight.Parent = char
        billboard.Parent = char:WaitForChild("HumanoidRootPart")
    end

    player.CharacterAdded:Connect(setupChar)
    if player.Character then setupChar(player.Character) end
end

Players.PlayerAdded:Connect(createESP)
for _, p in pairs(Players:GetPlayers()) do createESP(p) end

RunService.RenderStepped:Connect(function()
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("PlayerHighlight") then
            p.Character.PlayerHighlight.Enabled = ProfileSettings.PlayerESPActive
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp:FindFirstChild("PlayerLabel") then
                hrp.PlayerLabel.Enabled = ProfileSettings.PlayerESPActive
            end
        end
    end
end)

-- ---------------------------------------------------------------------
--  2. AUTOMATION & CORE LOGIC
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
        if hum and hum.Health > 0 then
            -- Always restore health to max when No Damage is active
            -- This prevents damage from accumulating faster than healing
            hum.Health = hum.MaxHealth
        end
    end
    
    -- Continuous ragdoll prevention (runs every frame for reliability)
    if ProfileSettings.NoRagdollActive then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            -- Disable PlatformStand to prevent ragdoll
            if hum.PlatformStand then
                hum.PlatformStand = false
            end
            -- Force humanoid state to Standing/Running to prevent ragdoll states
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
    
    -- Continuous multi-jump hold effect
    if ProfileSettings.MultiJumpActive and spaceHeld then
        local char = LocalPlayer.Character
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        if rootPart then
            -- Apply continuous upward velocity while space is held
            local currentVelocity = rootPart.Velocity
            rootPart.Velocity = Vector3.new(currentVelocity.X, 50, currentVelocity.Z)
        end
    end
end)

ProximityPromptService.PromptShown:Connect(function(prompt)
    if ProfileSettings.InstantInteractions then
        prompt.HoldDuration = 0
    end
end)

-- ---------------------------------------------------------------------
--  2.a LAG FX: Animation frame-skipping + jitter (merged from glitch.lua)
-- ---------------------------------------------------------------------

local FRAME_DURATION = 1 / math.max(1, ProfileSettings.LagFPS) -- will be recalculated when FPS changes
local function recalcFrameDuration()
    FRAME_DURATION = 1 / math.max(1, ProfileSettings.LagFPS)
end

-- Force Speed (applies the common speed multiplier)
local function forceSpeed(hum)
    if hum and hum:IsA("Humanoid") then
        hum.WalkSpeed = 16 * getCurrentSpeed()
    end
end

-- The core "Lag" engine applied to an AnimationTrack
local function applyLagEffect(track)
    if not track then return end

    local lastUpdate = 0
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not track or not track.IsPlaying then
            if connection then connection:Disconnect() end
            return
        end

        if ProfileSettings.LagFXActive then
            -- pause animation and manually update TimePosition intermittently to simulate frame skipping
            track:AdjustSpeed(0)

            if os.clock() - lastUpdate >= FRAME_DURATION then
                local skip = 0.15 + (math.random() * 0.1)
                -- jump forward in animation timeline to create "teleport" effect
                track.TimePosition = track.TimePosition + skip
                lastUpdate = os.clock()
            end
        else
            -- restore normal playback speed according to current multiplier
            local speed = getCurrentSpeed()
            track:AdjustSpeed(speed)
        end
    end)
end

-- Hook into Animator/Humanoid to apply lag effects to tracks
local function hookHumanoid(hum)
    if not hum or not hum:IsA("Humanoid") then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    -- Watch for new animations
    animator.AnimationPlayed:Connect(function(track)
        applyLagEffect(track)
    end)

    -- Apply to existing playing tracks
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        applyLagEffect(track)
    end

    -- Keep the humanoid walk speed consistent with the profile multiplier
    hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        forceSpeed(hum)
    end)
    forceSpeed(hum)
end

-- ---------------------------------------------------------------------
--  ManageCharacter: extended to hook humanoid animations
-- ---------------------------------------------------------------------

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

    -- Hook animator for lag FX
    pcall(function()
        hookHumanoid(humanoid)
    end)

    humanoid.Died:Connect(function()
        if speedConnection then speedConnection:Disconnect() end
        if stateConnection then stateConnection:Disconnect() end
    end)
end

if LocalPlayer and LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end
if LocalPlayer then LocalPlayer.CharacterAdded:Connect(ManageCharacter) end

-- Space key input handling for multi-jump
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == Enum.KeyCode.Space and ProfileSettings.MultiJumpActive then
        spaceHeld = true
        jumpCount = jumpCount + 1  -- Increment jump count on key press
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        spaceHeld = false  -- Space released
    end
end)

-- ---------------------------------------------------------------------
--  3. GRAPHICAL USER INTERFACE (Merged)
-- ---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 400)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Scrollable Container
local ScrollFrame = Instance.new("ScrollingFrame", MainFrame)
ScrollFrame.Size = UDim2.new(1, 0, 1, -40)
ScrollFrame.Position = UDim2.new(0, 0, 0, 40)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 600) -- extended for extra toggle
ScrollFrame.ScrollBarThickness = 6

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
    Button.Parent = ScrollFrame
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

local function createButton(name, positionY, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0.9, 0, 0, 35)
    Button.Position = UDim2.new(0.05, 0, 0, positionY)
    Button.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
    Button.Text = name
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Parent = ScrollFrame
    Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 4)
    Button.MouseButton1Click:Connect(callback)
end

-- Original Toggles (positions preserved, with Lag FX added)
createToggle("Auto Buy Bombs", 10, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 60, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("Infinite Multi-Jump", 110, function(s) ProfileSettings.MultiJumpActive = s end)
createToggle("No Ragdoll", 160, function(s) ProfileSettings.NoRagdollActive = s end)
createToggle("No Damage", 210, function(s) ProfileSettings.NoDamageActive = s end)
createToggle("Player ESP", 260, function(s) ProfileSettings.PlayerESPActive = s end)

-- Lag FX toggle (merged)
createToggle("Lag FX", 310, function(s)
    ProfileSettings.LagFXActive = s
    -- on toggle off, restore speeds for existing animation tracks
    if not s and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                pcall(function()
                    track:AdjustSpeed(getCurrentSpeed())
                end)
            end
        end
    end
end)

-- TELEPORT button moved down slightly to make room for Lag FX toggle
createButton("TELEPORT TO SPAWN", 360, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local spawn = workspace:FindFirstChild("SpawnLocation", true)
        if spawn then
            TweenService:Create(char.HumanoidRootPart, TweenInfo.new(0.5), {CFrame = spawn.CFrame + Vector3.new(0, 3, 0)}):Play()
        end
    end
end)

-- ---------------------------------------------------------------------
--  4. SLIDER ELEMENT (Restored & moved)
-- ---------------------------------------------------------------------

local SliderContainer = Instance.new("Frame")
SliderContainer.Size = UDim2.new(0.9, 0, 0, 45)
SliderContainer.Position = UDim2.new(0.05, 0, 0, 410)
SliderContainer.BackgroundTransparency = 1
SliderContainer.Parent = ScrollFrame

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

-- Allow toggling the panel with Insert (already present originally)
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end
end)

-- ---------------------------------------------------------------------
--  5. (Optional) Console controls for Lag FX tuning
-- ---------------------------------------------------------------------
-- If you want to expose FPS tuning (how laggy) via code, you can modify:
--   ProfileSettings.LagFPS = <number>
-- then call recalcFrameDuration()
-- Example:
--   ProfileSettings.LagFPS = 2
--   recalcFrameDuration()

-- ensure frame duration reflects initial value
recalcFrameDuration()
