-- mineamountain_script.lua

-- Import required services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Lower FPS = More "laggy"
local FPS = 3
local FRAME_DURATION = 1 / FPS
local EffectEnabled = false
local CurrentSpeed = 1.0

-- Force Speed
local function forceSpeed(hum)
    hum.WalkSpeed = 16 * CurrentSpeed
end

-- The core "Lag" engine
local function applyLagEffect(track)
    local lastUpdate = 0

    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not track or not track.IsPlaying then
            connection:Disconnect()
            return
        end

        if EffectEnabled then
            -- We pause the animation by setting speed to 0
            -- and only manually updating TimePosition every few frames
            track:AdjustSpeed(0)

            if os.clock() - lastUpdate >= FRAME_DURATION then
                -- Skip forward by a larger chunk to simulate "lag" teleportation
                local skip = 0.15 + (math.random() * 0.1)
                track.TimePosition = track.TimePosition + skip
                lastUpdate = os.clock()
            end
        else
            -- Restore normal playback
            track:AdjustSpeed(CurrentSpeed)
        end
    end)
end

-- Hook into Humanoid
local function hookHumanoid(hum)
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    -- Watch for new animations
    animator.AnimationPlayed:Connect(function(track)
        applyLagEffect(track)
    end)

    -- Apply to existing
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        applyLagEffect(track)
    end

    hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function() forceSpeed(hum) end)
    forceSpeed(hum)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then hookHumanoid(hum) end
end)
if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
    hookHumanoid(LocalPlayer.Character.Humanoid)
end

-- Lag FX script
local function createLagFX()
    local RunService = game:GetService("RunService")
    local Users = game:GetService("Users")
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")

    -- Lower FPS = More "laggy"
    local FPS = 3
    local FRAME_DURATION = 1 / FPS
    local EffectEnabled = false
    local CurrentSpeed = 1.0

    -- Force Speed
    local function forceSpeed(hum)
        hum.WalkSpeed = 16 * CurrentSpeed
    end

    -- The core "Lag" engine
    local function applyLagEffect(track)
        local lastUpdate = 0

        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not track or not track.IsPlaying then
                connection:Disconnect()
                return
            end

            if EffectEnabled then
                -- We pause the animation by setting speed to 0
                -- and only manually updating TimePosition every few frames
                track:AdjustSpeed(0)

                if os.clock() - lastUpdate >= FRAME_DURATION then
                    -- Skip forward by a larger chunk to simulate "lag" teleportation
                    local skip = 0.15 + (math.random() * 0.1)
                    track.TimePosition = track.TimePosition + skip
                    lastUpdate = os.clock()
                end
            else
                -- Restore normal playback
                track:AdjustSpeed(CurrentSpeed)
            end
        end)
    end

    -- Hook into Humanoid
    local function hookHumanoid(hum)
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then return end

        -- Watch for new animations
        animator.AnimationPlayed:Connect(function(track)
            applyLagEffect(track)
        end)

        -- Apply to existing
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            applyLagEffect(track)
        end

        hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function() forceSpeed(hum) end)
        forceSpeed(hum)
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then hookHumanoid(hum) end
    end)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        hookHumanoid(LocalPlayer.Character.Humanoid)
    end

    return applyLagEffect
end

-- Create lag FX script
local LagFX = createLagFX()

-- Main frame for GUI
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 140)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Toggle button for lag FX
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0.85, 0, 0, 36)
ToggleButton.Position = UDim2.new(0.075, 0, 0.1, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(110, 60, 60)
ToggleButton.Text = "Lag FX: OFF"
ToggleButton.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 4)

ToggleButton.MouseButton1Click:Connect(function()
    EffectEnabled = not EffectEnabled
    ToggleButton.Text = EffectEnabled and "Lag FX: ON" or "Lag FX: OFF"
    ToggleButton.BackgroundColor3 = EffectEnabled and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(110, 60, 60)

    -- Reset speed for all tracks when toggling off
    if not EffectEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        for _, track in pairs(LocalPlayer.Character.Humanoid:FindFirstChildOfClass("Animator"):GetPlayingAnimationTracks()) do
            track:AdjustSpeed(CurrentSpeed)
        end
    end
end)

-- Slider for speed
local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(1, 0, 0, 20)
SliderLabel.Position = UDim2.new(0, 0, 0.55, 0)
SliderLabel.Text = "Walk Speed: 1.00x"
SliderLabel.TextColor3 = Color3.new(1, 1, 1)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Font = Enum.Font.SourceSans
SliderLabel.TextSize = 12

local SliderBg = Instance.new("Frame")
SliderBg.Size = UDim2.new(0.85, 0, 0, 6)
SliderBg.Position = UDim2.new(0.075, 0, 0.75, 0)
SliderBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(0, 3)

local SliderBtn = Instance.new("TextButton")
SliderBtn.Size = UDim2.new(0, 14, 0, 14)
SliderBtn.Position = UDim2.new(1, -7, 0.5, -7)
SliderBtn.BackgroundColor3 = Color3.new(1, 1, 1)
SliderBtn.Text = ""
Instance.new("UICorner", SliderBtn).CornerRadius = UDim.new(1, 0)

local function updateSpeed(rel)
    CurrentSpeed = 0.25 + (rel * 0.75)
    CurrentSpeed = math.floor((CurrentSpeed * 4) + 0.5) / 4
    local snappedRel = (CurrentSpeed - 0.25) / 0.75
    SliderBtn.Position = UDim2.new(snappedRel, -7, 0.5, -7)
    SliderLabel.Text = "Walk Speed: " .. string.format("%.2f", CurrentSpeed) .. "x"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        forceSpeed(LocalPlayer.Character.Humanoid)
    end
end

local isDragging = false
SliderBtn.MouseButton1Down:Connect(function() isDragging = true end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end end)
UserInputService.InputChanged:Connect(function(input)
    if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local rel = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
        updateSpeed(rel)
    end
end)
