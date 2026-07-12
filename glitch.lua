-- =====================================================================
--  STEPPED ANIMATION FX (12 FPS) - DEBUGGED VERSION
-- =====================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local STEPS_PER_SECOND = 12
local STEP_INTERVAL = 1 / STEPS_PER_SECOND
local EffectEnabled = true
local hijackedTracks = {}

-- 1. Helper: Disable Default Animate Script so it stops fighting us
local function disableDefaultAnimate()
    local char = LocalPlayer.Character
    if char then
        local animate = char:FindFirstChild("Animate")
        if animate and animate:IsA("Script") then
            animate.Disabled = true
        end
    end
end

-- 2. Stepped Logic
local function stepAnimationTrack(track)
    if hijackedTracks[track] then return end
    hijackedTracks[track] = true

    -- Force high priority so the engine doesn't overwrite our poses
    pcall(function() track.Priority = Enum.AnimationPriority.Action4 end)

    local accumulatedTime = 0
    local lastStepTime = 0
    local heldPosition = 0

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if not track or not track.IsPlaying then
            hijackedTracks[track] = nil
            connection:Disconnect()
            return
        end

        if EffectEnabled then
            accumulatedTime = accumulatedTime + dt
            if accumulatedTime - lastStepTime >= STEP_INTERVAL then
                lastStepTime = accumulatedTime
                heldPosition = track.TimePosition
            end
            
            track:AdjustSpeed(0)
            track.TimePosition = heldPosition
        else
            track:AdjustSpeed(1)
        end
    end)
end

-- 3. Hooking logic
local function hookHumanoid(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
    if not animator then return end

    animator.AnimationPlayed:Connect(stepAnimationTrack)
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        stepAnimationTrack(track)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    disableDefaultAnimate()
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then hookHumanoid(hum) end
end)

if LocalPlayer.Character then
    disableDefaultAnimate()
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then hookHumanoid(hum) end
end

-- =====================================================================
--  GUI
-- =====================================================================

local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Size = UDim2.new(0, 220, 0, 90); MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25); MainFrame.Active = true; MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local ToggleButton = Instance.new("TextButton", MainFrame); ToggleButton.Size = UDim2.new(0.85, 0, 0, 36); ToggleButton.Position = UDim2.new(0.075, 0, 0.3, 0); ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 110, 60); ToggleButton.Text = "Stepped FX: ON"; ToggleButton.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 4)

ToggleButton.MouseButton1Click:Connect(function()
    EffectEnabled = not EffectEnabled
    ToggleButton.Text = EffectEnabled and "Stepped FX: ON" or "Stepped FX: OFF"
    ToggleButton.BackgroundColor3 = EffectEnabled and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(110, 60, 60)
end)

UserInputService.InputBegan:Connect(function(i, g) if not g and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
