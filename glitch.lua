-- =====================================================================
--  STEPPED ANIMATION FX (12 FPS) + VELOCITY-BASED SPEED CONTROLLER
-- =====================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local STEPS_PER_SECOND = 12
local STEP_INTERVAL = 1 / STEPS_PER_SECOND
local EffectEnabled = false 
local CurrentSpeed = 1.0
local hijackedTracks = {}

-- Velocity Controller: Cap the character's velocity so they move slower
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        local root = char.HumanoidRootPart
        local hum = char.Humanoid
        
        -- Override speed via Velocity capping (this works even if game resets WalkSpeed)
        if hum.MoveDirection.Magnitude > 0 then
            local currentVel = root.Velocity
            local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
            
            if horizontalVel.Magnitude > (16 * CurrentSpeed) then
                root.Velocity = (horizontalVel.Unit * (16 * CurrentSpeed)) + Vector3.new(0, currentVel.Y, 0)
            end
        end
    end
end)

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
            if os.clock() >= nextUpdate then
                local jitter = (math.random() - 0.5) * 0.05
                track.TimePosition = math.max(0, track.TimePosition + jitter)
                track:AdjustSpeed(CurrentSpeed)
                nextUpdate = os.clock() + STEP_INTERVAL
            else
                track:AdjustSpeed(0)
            end
        else
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
local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Size = UDim2.new(0, 220, 0, 140); MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25); MainFrame.Active = true; MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local ToggleButton = Instance.new("TextButton", MainFrame); ToggleButton.Size = UDim2.new(0.85, 0, 0, 36); ToggleButton.Position = UDim2.new(0.075, 0, 0.1, 0); ToggleButton.BackgroundColor3 = Color3.fromRGB(110, 60, 60); ToggleButton.Text = "Stepped FX: OFF"; ToggleButton.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 4)

ToggleButton.MouseButton1Click:Connect(function()
    EffectEnabled = not EffectEnabled
    ToggleButton.Text = EffectEnabled and "Stepped FX: ON" or "Stepped FX: OFF"
    ToggleButton.BackgroundColor3 = EffectEnabled and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(110, 60, 60)
end)

local SliderLabel = Instance.new("TextLabel", MainFrame); SliderLabel.Size = UDim2.new(1, 0, 0, 20); SliderLabel.Position = UDim2.new(0, 0, 0.55, 0); SliderLabel.Text = "Walk Speed: 1.0"; SliderLabel.TextColor3 = Color3.new(1, 1, 1); SliderLabel.BackgroundTransparency = 1; SliderLabel.Font = Enum.Font.SourceSans; SliderLabel.TextSize = 12
local SliderBg = Instance.new("Frame", MainFrame); SliderBg.Size = UDim2.new(0.85, 0, 0, 6); SliderBg.Position = UDim2.new(0.075, 0, 0.75, 0); SliderBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(0, 3)

local SliderBtn = Instance.new("TextButton", SliderBg); SliderBtn.Size = UDim2.new(0, 14, 0, 14); SliderBtn.Position = UDim2.new(1, -7, 0.5, -7); SliderBtn.BackgroundColor3 = Color3.new(1, 1, 1); SliderBtn.Text = ""
Instance.new("UICorner", SliderBtn).CornerRadius = UDim.new(1, 0)

local function updateSpeed(rel)
    local raw = 0.3 + (rel * 0.7)
    CurrentSpeed = math.floor((raw * 10) + 0.5) / 10
    
    local snappedRel = (CurrentSpeed - 0.3) / 0.7
    SliderBtn.Position = UDim2.new(snappedRel, -7, 0.5, -7)
    SliderLabel.Text = "Walk Speed: " .. string.format("%.1f", CurrentSpeed)
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

UserInputService.InputBegan:Connect(function(i, g) if not g and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
