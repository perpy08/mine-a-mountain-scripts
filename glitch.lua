-- =====================================================================
--  STEPPED ANIMATION FX (12 FPS) - INITIALIZED OFF
-- =====================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local STEPS_PER_SECOND = 12
local STEP_INTERVAL = 1 / STEPS_PER_SECOND
-- Defaulted to false as requested
local EffectEnabled = false 
local hijackedTracks = {}

local function stepAnimationTrack(track)
    if hijackedTracks[track] then return end
    hijackedTracks[track] = true

    local nextUpdate = 0
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not track or not track.IsPlaying then
            hijackedTracks[track] = nil
            connection:Disconnect()
            return
        end

        if EffectEnabled then
            -- "12fps" logic: Update only when interval is reached
            if os.clock() >= nextUpdate then
                track:AdjustSpeed(1) -- Move
                nextUpdate = os.clock() + STEP_INTERVAL
            else
                track:AdjustSpeed(0) -- Freeze pose
            end
        else
            -- Ensure effect is fully disabled by returning speed to normal
            track:AdjustSpeed(1)
        end
    end)
end

local function hookHumanoid(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
    if not animator then return end
    animator.AnimationPlayed:Connect(stepAnimationTrack)
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        stepAnimationTrack(track)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then hookHumanoid(hum) end
end)
if LocalPlayer.Character then
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then hookHumanoid(hum) end
end

-- =====================================================================
--  GUI
-- =====================================================================

local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Size = UDim2.new(0, 220, 0, 90); MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25); MainFrame.Active = true; MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Initialized to OFF state
local ToggleButton = Instance.new("TextButton", MainFrame); ToggleButton.Size = UDim2.new(0.85, 0, 0, 36); ToggleButton.Position = UDim2.new(0.075, 0, 0.3, 0); ToggleButton.BackgroundColor3 = Color3.fromRGB(110, 60, 60); ToggleButton.Text = "Stepped FX: OFF"; ToggleButton.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 4)

ToggleButton.MouseButton1Click:Connect(function()
    EffectEnabled = not EffectEnabled
    ToggleButton.Text = EffectEnabled and "Stepped FX: ON" or "Stepped FX: OFF"
    ToggleButton.BackgroundColor3 = EffectEnabled and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(110, 60, 60)
end)

UserInputService.InputBegan:Connect(function(i, g) if not g and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
