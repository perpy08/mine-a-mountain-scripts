--[[
    STEPPED ANIMATION EFFECT (e.g. "12fps" stop-motion look)
    ---------------------------------------------------------
    Place this as a LocalScript inside StarterPlayerScripts.

    How it works:
    - Your character's animations normally play smoothly every render frame
      (interpolated), because AnimationTracks update continuously.
    - This script takes manual control: it pauses that smooth interpolation
      and instead advances the animation's TimePosition only N times per
      second (default 12), holding the pose steady between updates.
    - Your actual game framerate, camera, physics, and everyone else's
      animations are completely unaffected — this only changes how YOUR
      character's animation *looks* to viewers.

    Tweak STEPS_PER_SECOND to taste: 8-12 gives a strong stop-motion feel,
    15-24 gives a subtler "choppy" look.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local STEPS_PER_SECOND = 12
local STEP_INTERVAL = 1 / STEPS_PER_SECOND

-- Master on/off switch, controlled by the GUI button
local EffectEnabled = true

-- Tracks we've already hijacked, so we don't double-process the same one
local hijackedTracks = {}

local function stepAnimationTrack(track)
    if hijackedTracks[track] then return end
    hijackedTracks[track] = true

    -- Let the track keep "playing" internally for looping/marker logic,
    -- but we override how its TimePosition is perceived visually by
    -- freezing/advancing it manually via AdjustSpeed tricks.

    local accumulatedTime = 0
    local lastStepTime = 0
    local heldPosition = 0

    local connection
    connection = RunService.RenderStepped:Connect(function(dt)
        if not track.IsPlaying then
            connection:Disconnect()
            hijackedTracks[track] = nil
            return
        end

        if not EffectEnabled then
            -- Effect toggled off: let the track play normally again
            pcall(function() track:AdjustSpeed(1) end)
            return
        end

        accumulatedTime = accumulatedTime + dt

        if accumulatedTime - lastStepTime >= STEP_INTERVAL then
            lastStepTime = accumulatedTime
            heldPosition = track.TimePosition
        end

        -- Force the track back to the last "stepped" position every frame,
        -- so it visually holds still between steps instead of interpolating.
        track:AdjustSpeed(0.0001) -- near-zero so internal playback barely creeps
        track.TimePosition = heldPosition
    end)
end

local function onAnimationPlayed(_, animationTrack)
    stepAnimationTrack(animationTrack)
end

local function hookHumanoid(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = humanoid:WaitForChild("Animator", 5)
    end
    if not animator then return end

    animator.AnimationPlayed:Connect(onAnimationPlayed)

    -- Catch any tracks already playing when this script starts
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        stepAnimationTrack(track)
    end
end

local function onCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        hookHumanoid(humanoid)
    end
end

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

--[[
    -----------------------------------------------------------------
    SIMPLE GUI: toggle button + Insert key to show/hide the panel
    -----------------------------------------------------------------
]]

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SteppedAnimationPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 90)
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 8)
FrameCorner.Parent = MainFrame

local HeaderLabel = Instance.new("TextLabel")
HeaderLabel.Size = UDim2.new(1, 0, 0, 30)
HeaderLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HeaderLabel.Text = "Stepped Animation"
HeaderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
HeaderLabel.Font = Enum.Font.SourceSansBold
HeaderLabel.TextSize = 14
HeaderLabel.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = HeaderLabel

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0.85, 0, 0, 36)
ToggleButton.Position = UDim2.new(0.075, 0, 0, 42)
ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
ToggleButton.Text = "Stepped FX: ON"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.SourceSans
ToggleButton.TextSize = 14
ToggleButton.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 4)
ToggleCorner.Parent = ToggleButton

ToggleButton.MouseButton1Click:Connect(function()
    EffectEnabled = not EffectEnabled

    if EffectEnabled then
        ToggleButton.Text = "Stepped FX: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
    else
        ToggleButton.Text = "Stepped FX: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(110, 60, 60)
    end
end)

-- Insert key shows/hides the whole panel (doesn't affect the effect itself)
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)
