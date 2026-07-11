-- =====================================================================
--  MINE A MOUNTAIN: DYNAMIC SMART HUB (OPTIMIZED)
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
    MultiJumpActive = false,
    CurrentSpeedMultiplier = 1.0,
    CrystalBoostValue = 0
}

local maxBonusJumps = 10
local jumpCount = 0

-- Remotes
local BUY_BOMB_REMOTE = nil
local LUCK_REMOTE = nil

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage
if remotesFolder then
    BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
    LUCK_REMOTE = remotesFolder:FindFirstChild("CrystalLuck") or remotesFolder:FindFirstChild("CrystalBoost") or remotesFolder:FindFirstChild("LuckRemote")
end

-- ---------------------------------------------------------------------
--  1. AUTOMATION ENGINE
-- ---------------------------------------------------------------------
task.spawn(function()
    local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            for _, bombName in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function()
                    if BUY_BOMB_REMOTE:IsA("RemoteFunction") then BUY_BOMB_REMOTE:InvokeServer(bombName) else BUY_BOMB_REMOTE:FireServer(bombName) end
                end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

ProximityPromptService.PromptShown:Connect(function(prompt)
    if ProfileSettings.InstantInteractions then prompt.HoldDuration = 0 end
end)

-- ---------------------------------------------------------------------
--  2. CHARACTER LOGIC
-- ---------------------------------------------------------------------
local function ManageCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
        humanoid.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Landed then jumpCount = 0 end
        end)
    end
end

if LocalPlayer and LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(ManageCharacter)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.Space and ProfileSettings.MultiJumpActive then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hum and root and jumpCount < maxBonusJumps then
            jumpCount += 1
            root.Velocity = Vector3.new(root.Velocity.X, hum.JumpPower, root.Velocity.Z)
        end
    end
end)

-- ---------------------------------------------------------------------
--  3. GUI
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 250, 0, 250)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
MainFrame.Active = true
MainFrame.Draggable = true

local function createToggle(name, positionY, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, positionY)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(220, 80, 80)
    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.BackgroundColor3 = on and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(40, 40, 40)
        btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(220, 80, 80)
        btn.Text = name .. (on and ": ON" or ": OFF")
        callback(on)
    end)
end

createToggle("Auto Buy Bombs", 10, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 50, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("Infinite Multi-Jump", 90, function(s) ProfileSettings.MultiJumpActive = s end)

-- Speed Slider
local SpeedLabel = Instance.new("TextLabel", MainFrame)
SpeedLabel.Position = UDim2.new(0.05, 0, 0, 130)
SpeedLabel.Text = "WalkSpeed Multiplier: 1.0x"
SpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedLabel.BackgroundTransparency = 1

local SpeedSlider = Instance.new("TextButton", MainFrame)
SpeedSlider.Size = UDim2.new(0.9, 0, 0, 10)
SpeedSlider.Position = UDim2.new(0.05, 0, 0, 150)
SpeedSlider.MouseButton1Click:Connect(function(x, y)
    local pct = math.clamp((x - SpeedSlider.AbsolutePosition.X) / SpeedSlider.AbsoluteSize.X, 0, 1)
    local val = math.floor(((1.0 + (pct * 4.0)) * 2) + 0.5) / 2
    ProfileSettings.CurrentSpeedMultiplier = val
    SpeedLabel.Text = "WalkSpeed Multiplier: " .. val .. "x"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16 * val
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end
end)
